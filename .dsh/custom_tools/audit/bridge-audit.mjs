// 桥接会话专项：可见工具集、注入式断裂、断裂代价 vs 节省，以及断裂时历史规模。
import fs from 'node:fs';
import path from 'node:path';
import zlib from 'node:zlib';
import crypto from 'node:crypto';

const MAGIC = Buffer.from([0x28, 0xb5, 0x2f, 0xfd]);
function decompressAll(file) {
  const buf = fs.readFileSync(file);
  const pos = []; let i = 0;
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
const walk = (d) => { let es = []; try { es = fs.readdirSync(d, { withFileTypes: true }); } catch { return; } for (const e of es) { const f = path.join(d, e.name); if (e.isDirectory()) walk(f); else if (e.name === 'session.v4.jsonl.zstd') files.push(f); } };
walk(root);
files.sort((a, b) => fs.statSync(b).mtimeMs - fs.statSync(a).mtimeMs);

const median = (a) => { if (!a.length) return 0; const s = [...a].sort((x, y) => x - y); const m = Math.floor(s.length / 2); return s.length % 2 ? s[m] : (s[m - 1] + s[m]) / 2; };
const mean = (a) => a.length ? a.reduce((x, y) => x + y, 0) / a.length : 0;

const sessions = [];
for (const f of files) {
  const events = decompressAll(f).split('\n').filter(Boolean).map((l) => { try { return JSON.parse(l); } catch { return null; } }).filter(Boolean);
  if (!events.length) continue;
  const sid = path.basename(path.dirname(f));
  const mtime = fs.statSync(f).mtimeMs;
  let header = null, systemLen = 0;
  const rows = [], headers = [];
  for (const e of events) {
    if (e.type === 'request/header' && e.data?.header?.tools) {
      const tools = e.data.header.tools;
      const names = tools.map((t) => t.name);
      header = { hash: crypto.createHash('sha1').update(JSON.stringify(tools)).digest('hex').slice(0, 10), names, count: tools.length, chars: JSON.stringify(tools).length };
      headers.push({ ...header, step: rows.length });
    } else if (e.type === 'system/message') {
      const m = e.data?.message || e.data || {}; systemLen = (typeof m === 'string' ? m : JSON.stringify(m)).length;
    } else if (e.type === 'assistant/message' && e.data?.usage && header) {
      const u = e.data.usage; const input = u.inputTokens || 0, cr = u.cacheReadTokens || 0, cw = u.cacheWriteTokens || 0, out = u.outputTokens || 0;
      const prompt = input + cr + cw; const prev = rows[rows.length - 1];
      rows.push({ step: rows.length, headerHash: header.hash, count: header.count, chars: header.chars, input, cacheRead: cr, prompt, hit: prompt ? cr / prompt : null, changed: prev ? prev.headerHash !== header.hash : true, time: e.time || 0 });
    }
  }
  if (!rows.length) continue;
  const allCounts = headers.map((h) => h.count);
  const minCount = Math.min(...allCounts);
  sessions.push({ sid, mtime, rows, headers, minCount, systemLen });
}

const bridge = sessions.filter((s) => s.minCount <= 30);
const full = sessions.filter((s) => s.minCount > 30 && s.rows.length > 5);
console.log(`TOTAL SESSIONS ${sessions.length}  bridgeSessions=${bridge.length}  fullSessions=${full.length}`);

function report(label, ss, deltaT) {
  console.log(`\n### ${label}`);
  let agg = { steps: 0, breaks: 0, breakCost: 0, savings01: 0, savings30: 0, stable: 0, changedSteps: 0 };
  for (const s of ss) {
    const rows = s.rows;
    const changed = rows.filter((r, i) => i > 0 && r.changed);
    const stable = rows.filter((r, i) => i > 0 && !r.changed);
    const baseline = median(stable.map((r) => r.input)) || 0;
    const breakCost = changed.reduce((a, r) => a + Math.max(0, r.input - baseline), 0);
    const save01 = 0.1 * deltaT * stable.length;
    const save30 = deltaT / 30 * stable.length;
    agg.steps += rows.length; agg.breaks += changed.length; agg.breakCost += breakCost;
    agg.savings01 += save01; agg.savings30 += save30; agg.stable += stable.length; agg.changedSteps += changed.length;
    const changedDetail = changed.map((r) => `${Math.round(r.prompt / 1000)}k/${Math.round(r.input / 1000)}k@${r.step}`).slice(0, 6).join(' ');
    console.log(`${s.sid.slice(0, 24).padEnd(24)} ${new Date(s.mtime).toISOString().slice(5, 16)} steps=${String(rows.length).padStart(3)} visTok=${Math.round(median(rows.map((r) => r.chars)) / 4)} headerCounts=[${s.headers.map((h) => h.count).join(',')}] breaks=${changed.length} cost=${Math.round(breakCost)} ${changedDetail}`);
  }
  console.log(`AGG steps=${agg.steps} breaks=${agg.breaks} breakCost=${Math.round(agg.breakCost)} save01=${Math.round(agg.savings01)} R01=${(agg.breakCost / agg.savings01 || 0).toFixed(2)} save30=${Math.round(agg.savings30)} R30=${(agg.breakCost / agg.savings30 || 0).toFixed(2)}`);
}

// ΔT: 全量工具 token 33183 vs 可见工具 token（按会话中位数）；再扣 manifest 增量（桥接系统提示约 +1.5k 字符 ≈ 375 token）
report('BRIDGE SESSIONS (min toolCount <= 30)', bridge, 33183 - 2500 - 375);
report('FULL-TOOL SESSIONS (min toolCount > 30, steps>5)', full, 0);

// 头部变更明细：注入（+1）还是批量（大变化）
console.log('\n### header name diffs in bridge sessions (first 3)');
for (const s of bridge.slice(0, 3)) {
  console.log(`-- ${s.sid.slice(0, 24)}`);
  for (let i = 1; i < s.headers.length; i++) {
    const a = new Set(s.headers[i - 1].names), b = new Set(s.headers[i].names);
    const added = [...b].filter((x) => !a.has(x)), removed = [...a].filter((x) => !b.has(x));
    console.log(`  step=${s.headers[i].step} ${s.headers[i - 1].count}->${s.headers[i].count} +[${added.slice(0, 6).join(',')}] -[${removed.slice(0, 4).join(',')}]`);
  }
}
