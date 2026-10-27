// 决策口径：桥接稳态会话的净收益（token 当量），以及断裂代价分位。
import fs from 'node:fs';
import path from 'node:path';
import zlib from 'node:zlib';

const MAGIC = Buffer.from([0x28, 0xb5, 0x2f, 0xfd]);
function dec(file) {
  const buf = fs.readFileSync(file); const pos = []; let i = 0;
  while ((i = buf.indexOf(MAGIC, i)) !== -1) { pos.push(i); i += 4; }
  let t = '';
  for (let k = 0; k < pos.length; k++) { const end = k + 1 < pos.length ? pos[k + 1] : buf.length; try { t += zlib.zstdDecompressSync(buf.subarray(pos[k], end)).toString('utf8'); } catch {} }
  return t;
}
const root = path.join(process.env.DSH_HOME || path.join(process.env.USERPROFILE || '', '.dsh'), 'sessions');
const files = [];
const walk = (d) => { let es = []; try { es = fs.readdirSync(d, { withFileTypes: true }); } catch { return; } for (const e of es) { const f = path.join(d, e.name); if (e.isDirectory()) walk(f); else if (e.name === 'session.v4.jsonl.zstd') files.push(f); } };
walk(root);
files.sort((a, b) => fs.statSync(b).mtimeMs - fs.statSync(a).mtimeMs);
const INSTALL = new Date('2026-10-24T00:52:00+08:00').getTime();
const median = (a) => { if (!a.length) return 0; const s = [...a].sort((x, y) => x - y); const m = Math.floor(s.length / 2); return s.length % 2 ? s[m] : (s[m - 1] + s[m]) / 2; };
const p90 = (a) => { if (!a.length) return 0; const s = [...a].sort((x, y) => x - y); return s[Math.floor(s.length * 0.9)]; };

const sessions = [];
for (const f of files) {
  const events = dec(f).split('\n').filter(Boolean).map((l) => { try { return JSON.parse(l); } catch { return null; } }).filter(Boolean);
  if (!events.length) continue;
  let hdr = null; const rows = []; const headers = [];
  for (const e of events) {
    if (e.type === 'request/header' && e.data?.header?.tools) {
      const tools = e.data.header.tools;
      hdr = { count: tools.length, chars: JSON.stringify(tools).length, names: tools.map((x) => x.name), step: rows.length };
      headers.push(hdr);
    } else if (e.type === 'assistant/message' && e.data?.usage && hdr) {
      const u = e.data.usage; const input = u.inputTokens || 0, cr = u.cacheReadTokens || 0, cw = u.cacheWriteTokens || 0;
      const prompt = input + cr + cw; const prev = rows[rows.length - 1];
      rows.push({ input, cacheRead: cr, cacheWrite: cw, prompt, hit: prompt ? cr / prompt : 0, changed: prev ? prev.chars !== hdr.chars : true, count: hdr.count, chars: hdr.chars, step: rows.length });
    }
  }
  if (!rows.length) continue;
  const mtime = fs.statSync(f).mtimeMs;
  sessions.push({ sid: path.basename(path.dirname(f)), mtime, rows, headers, finalCount: headers[headers.length - 1].count, after: mtime >= INSTALL });
}

const bridgeSteady = sessions.filter((s) => s.after && s.finalCount <= 30 && s.rows.length > 3);
console.log('STEADY BRIDGE SESSIONS:', bridgeSteady.map((s) => s.sid.slice(0, 24)).join(', '));
console.log('\nmetric(session)        steps  visTok breaks  cost01   save01   net01   R01   net30   R30');
let agg = { steps: 0, breaks: 0, cost: 0, save01: 0, save30: 0 };
for (const s of bridgeSteady) {
  const rows = s.rows; const changed = rows.filter((r, i) => i > 0 && r.changed); const stable = rows.filter((r, i) => i > 0 && !r.changed);
  const base = median(stable.map((r) => r.input)) || 0;
  const cost = changed.reduce((a, r) => a + Math.max(0, r.input - base), 0);
  const visTok = median(rows.map((r) => r.chars)) / 4;
  const dT = 33183 - visTok - 375;
  const save01 = 0.1 * dT * stable.length, save30 = dT / 30 * stable.length;
  agg.steps += rows.length; agg.breaks += changed.length; agg.cost += cost; agg.save01 += save01; agg.save30 += save30;
  console.log(`${s.sid.slice(0, 22).padEnd(22)} ${String(rows.length).padStart(4)} ${String(Math.round(visTok)).padStart(6)} ${String(changed.length).padStart(5)} ${String(Math.round(cost)).padStart(8)} ${String(Math.round(save01)).padStart(8)} ${String(Math.round(save01 - cost)).padStart(8)} ${(cost / save01 || 0).toFixed(2).padStart(5)} ${String(Math.round(save30 - cost)).padStart(8)} ${(cost / save30 || 0).toFixed(2)}`);
}
console.log(`\nAGG net01=${Math.round(agg.save01 - agg.cost)} R01=${(agg.cost / agg.save01).toFixed(2)}  net30=${Math.round(agg.save30 - agg.cost)} R30=${(agg.cost / agg.save30).toFixed(2)}`);

// 断裂步的输入规模分位（所有会话）
const brk = [];
for (const s of sessions) {
  const stable = s.rows.filter((r, i) => i > 0 && !r.changed);
  const base = median(stable.map((r) => r.input)) || 0;
  for (const r of s.rows) if (r.changed && r.input > base + 2000) brk.push(r.input);
}
console.log(`\nBREAK STEPS n=${brk.length}  input tokens: median=${Math.round(median(brk))}  p90=${Math.round(p90(brk))}  max=${Math.round(Math.max(...brk))}`);
console.log('对 d=0.1：一次断裂≈' + Math.round(median(brk) / (0.1 * 33183)) + ' 步工具 schema 节省；d=1/30 ≈' + Math.round(median(brk) / (0.033 * 33183)) + ' 步');
