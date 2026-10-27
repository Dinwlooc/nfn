// 缓存审计：按步统计前缀命中率，定位工具集/系统提示变更造成的缓存断裂。
// 用法：node .dsh/public/tools/audit/cache-audit.mjs [maxSessions]
import fs from 'node:fs';
import path from 'node:path';
import zlib from 'node:zlib';
import crypto from 'node:crypto';

const MAGIC = Buffer.from([0x28, 0xb5, 0x2f, 0xfd]);
const limit = Number(process.argv[2] || 200);
const INSTALL_MS = new Date('2026-10-24T00:52:00+08:00').getTime();

function decompressAll(file) {
  const buf = fs.readFileSync(file);
  const pos = [];
  let i = 0;
  while ((i = buf.indexOf(MAGIC, i)) !== -1) { pos.push(i); i += 4; }
  let text = '';
  for (let k = 0; k < pos.length; k++) {
    const end = k + 1 < pos.length ? pos[k + 1] : buf.length;
    try { text += zlib.zstdDecompressSync(buf.subarray(pos[k], end)).toString('utf8'); } catch {}
  }
  return text;
}

const root = path.join(process.env.DSH_HOME || path.join(process.env.USERPROFILE || '', '.dsh'), 'sessions');
const files = [];
const walk = (dir) => {
  let entries = [];
  try { entries = fs.readdirSync(dir, { withFileTypes: true }); } catch { return; }
  for (const e of entries) {
    const full = path.join(dir, e.name);
    if (e.isDirectory()) walk(full);
    else if (e.name === 'session.v4.jsonl.zstd') files.push(full);
  }
};
walk(root);
files.sort((a, b) => fs.statSync(b).mtimeMs - fs.statSync(a).mtimeMs);
const picked = files.slice(0, limit);

const sessions = [];
const allRows = [];
const eventTypes = {};

for (const f of picked) {
  const text = decompressAll(f);
  const events = [];
  for (const line of text.split('\n')) {
    if (!line) continue;
    try { events.push(JSON.parse(line)); } catch {}
  }
  if (!events.length) continue;
  const sid = path.basename(path.dirname(f));
  let header = null, headerCount = 0, systemLen = 0, compaction = 0;
  const rows = [];
  for (const e of events) {
    eventTypes[e.type] = (eventTypes[e.type] || 0) + 1;
    if (e.type === 'request/header' && e.data?.header?.tools) {
      const tools = e.data.header.tools;
      const names = tools.map((t) => t.name).sort();
      header = {
        hash: crypto.createHash('sha1').update(JSON.stringify(tools)).digest('hex').slice(0, 10),
        namesHash: crypto.createHash('sha1').update(names.join('\n')).digest('hex').slice(0, 10),
        count: tools.length,
        chars: JSON.stringify(tools).length,
      };
      headerCount++;
    } else if (e.type === 'system/message') {
      const m = e.data?.message || e.data || {};
      const textVal = typeof m === 'string' ? m : JSON.stringify(m);
      systemLen = textVal.length;
    } else if (String(e.type).includes('compact')) {
      compaction++;
    } else if (e.type === 'assistant/message' && e.data?.usage && header) {
      const u = e.data.usage;
      const input = u.inputTokens || 0;
      const cacheRead = u.cacheReadTokens || 0;
      const cacheWrite = u.cacheWriteTokens || 0;
      const output = u.outputTokens || 0;
      const prompt = input + cacheRead + cacheWrite;
      const prev = rows[rows.length - 1];
      rows.push({
        sid, step: e.data.step, turn: e.data.turn, time: e.time || 0,
        headerHash: header.hash, namesHash: header.namesHash, toolCount: header.count, toolChars: header.chars,
        input, cacheRead, cacheWrite, output, prompt,
        hit: prompt ? cacheRead / prompt : null,
        headerChanged: prev ? prev.headerHash !== header.hash : true,
        firstStep: rows.length === 0,
      });
    }
  }
  if (!rows.length) continue;
  const mtime = fs.statSync(f).mtimeMs;
  sessions.push({
    sid, mtime, installEra: mtime >= INSTALL_MS ? 'after' : 'before',
    steps: rows.length, headerCount, compaction, systemLen,
    firstTime: rows[0].time, lastTime: rows[rows.length - 1].time,
  });
  allRows.push(...rows);
}

const mean = (a) => a.length ? a.reduce((x, y) => x + y, 0) / a.length : 0;
const median = (a) => {
  if (!a.length) return 0;
  const s = [...a].sort((x, y) => x - y);
  const m = Math.floor(s.length / 2);
  return s.length % 2 ? s[m] : (s[m - 1] + s[m]) / 2;
};

console.log(`SESSIONS ${sessions.length}/${files.length}  STEPS ${allRows.length}`);
console.log('EVENT_TYPES ' + JSON.stringify(Object.fromEntries(Object.entries(eventTypes).filter(([k]) => k !== 'assistant/message' && k !== 'request/header' && k !== 'tool/call' && k !== 'tool/result' && k !== 'step/start' && k !== 'step/end' && k !== 'session-log-deepseek/delivery-accepted'))));

const byEra = { before: allRows.filter((r) => sessions.find((s) => s.sid === r.sid)?.installEra === 'before'),
                after: allRows.filter((r) => sessions.find((s) => s.sid === r.sid)?.installEra === 'after') };

function summarize(label, rows) {
  const changed = rows.filter((r) => r.headerChanged && !r.firstStep);
  const stable = rows.filter((r) => !r.headerChanged && !r.firstStep);
  const post = rows.filter((r, i) => i > 0 && rows[i - 1].headerChanged);
  console.log(`\n[${label}] steps=${rows.length}  toolCount(median)=${median(rows.map((r) => r.toolCount))}  toolTok(median)=${Math.round(median(rows.map((r) => r.toolChars)) / 4)}`);
  for (const [name, arr] of [['all', rows], ['stable', stable], ['changed', changed], ['post-break', post]]) {
    if (!arr.length) continue;
    console.log(`  ${name.padEnd(10)} n=${String(arr.length).padStart(4)}  hit(mean)=${(mean(arr.map((r) => r.hit)) * 100).toFixed(2)}%  hit(med)=${(median(arr.map((r) => r.hit)) * 100).toFixed(2)}%  prompt(med)=${Math.round(median(arr.map((r) => r.prompt)))}  input(med)=${Math.round(median(arr.map((r) => r.input)))}  cacheRead(med)=${Math.round(median(arr.map((r) => r.cacheRead)))}`);
  }
}
summarize('before install', byEra.before);
summarize('after install', byEra.after);

// 每会话：断裂次数、断裂代价、稳定步节省（按 d=0.1 与 1/30）
const DELTA_T = 34552 - 1000; // 全量工具 schema vs 常驻可见工具（粗估）
const perSession = sessions.map((s) => {
  const rows = allRows.filter((r) => r.sid === s.sid);
  const changed = rows.filter((r, i) => i > 0 && r.headerChanged);
  const stable = rows.filter((r, i) => i > 0 && !r.headerChanged);
  const medStableInput = median(stable.map((r) => r.input)) || 0;
  const breakCost = changed.reduce((acc, r) => acc + Math.max(0, r.input - medStableInput), 0);
  const savings01 = 0.1 * DELTA_T * stable.length;
  const savings30 = DELTA_T / 30 * stable.length;
  return { ...s, breaks: changed.length, breakCost, savings01, savings30, R01: savings01 ? breakCost / savings01 : null, R30: savings30 ? breakCost / savings30 : null, medH: median(rows.map((r) => r.prompt)) };
}).sort((a, b) => b.mtime - a.mtime);

console.log('\n== 最近 20 个会话（按时间倒序）==');
console.log('era    steps breaks  promptMed  breakCost  save01  R01   save30  R30   compact  header');
for (const s of perSession.slice(0, 20)) {
  console.log(`${s.installEra.padEnd(6)} ${String(s.steps).padStart(4)} ${String(s.breaks).padStart(4)} ${String(Math.round(s.medH)).padStart(9)} ${String(Math.round(s.breakCost)).padStart(9)} ${String(Math.round(s.savings01)).padStart(8)} ${s.R01 == null ? '  -  ' : s.R01.toFixed(2)} ${String(Math.round(s.savings30)).padStart(8)} ${s.R30 == null ? '  -  ' : s.R30.toFixed(2)} ${String(s.compaction).padStart(6)} ${String(s.headerCount).padStart(6)}`);
}

console.log('\n== after 时代：断裂代价 / 节省 汇总（只看有断裂的会话）==');
for (const era of ['before', 'after']) {
  const ss = perSession.filter((s) => s.installEra === era);
  const withB = ss.filter((s) => s.breaks > 0);
  const sumB = ss.reduce((a, s) => a + s.breaks, 0);
  const sumCost = ss.reduce((a, s) => a + s.breakCost, 0);
  const sumSave01 = ss.reduce((a, s) => a + s.savings01, 0);
  const sumSave30 = ss.reduce((a, s) => a + s.savings30, 0);
  console.log(`${era}: sessions=${ss.length} withBreaks=${withB.length} totalBreaks=${sumB} sumBreakCost=${Math.round(sumCost)} save01=${Math.round(sumSave01)} R01=${(sumSave01 ? sumCost / sumSave01 : 0).toFixed(2)} save30=${Math.round(sumSave30)} R30=${(sumSave30 ? sumCost / sumSave30 : 0).toFixed(2)} medianBreaksPerSession=${median(ss.map((s) => s.breaks))}`);
}

// 工具集变化分布：变更前后 count 差
const changes = allRows.filter((r, i) => i > 0 && r.headerChanged);
console.log(`\nHEADER_CHANGES total=${changes.length}  (by era: before=${changes.filter((r) => byEra.before.includes(r)).length} after=${changes.filter((r) => byEra.after.includes(r)).length})`);
const deltaCounts = changes.map((r) => r.toolCount);
console.log('changed-step toolCount(med)=' + median(deltaCounts));
