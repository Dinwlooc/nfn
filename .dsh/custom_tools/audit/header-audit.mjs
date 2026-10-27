// 检查每个会话的请求头工具集：是否桥接生效、工具数、变更分类。
import fs from 'node:fs';
import path from 'node:path';
import zlib from 'node:zlib';
import crypto from 'node:crypto';

const MAGIC = Buffer.from([0x28, 0xb5, 0x2f, 0xfd]);
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
const walk = (d) => {
  let es = [];
  try { es = fs.readdirSync(d, { withFileTypes: true }); } catch { return; }
  for (const e of es) {
    const f = path.join(d, e.name);
    if (e.isDirectory()) walk(f);
    else if (e.name === 'session.v4.jsonl.zstd') files.push(f);
  }
};
walk(root);
files.sort((a, b) => fs.statSync(b).mtimeMs - fs.statSync(a).mtimeMs);
const picked = files.slice(0, Number(process.argv[2] || 14));
console.log('sid                           mtime            steps hdrs  toolCounts                 sysLen  firstStepTime');
for (const f of picked) {
  const events = decompressAll(f).split('\n').filter(Boolean).map((l) => { try { return JSON.parse(l); } catch { return null; } }).filter(Boolean);
  const counts = [];
  let sysLen = 0, hdrs = 0, first = '';
  for (const e of events) {
    if (e.type === 'request/header' && e.data?.header?.tools) { counts.push(e.data.header.tools.length); hdrs++; }
    if (e.type === 'system/message') { const m = e.data?.message || e.data || {}; sysLen = (typeof m === 'string' ? m : JSON.stringify(m)).length; }
    if (e.type === 'assistant/message' && !first) first = e.time || '';
  }
  const uniq = [...new Set(counts)].sort((a, b) => a - b).join(',');
  const steps = events.filter((e) => e.type === 'assistant/message').length;
  console.log(`${path.basename(path.dirname(f)).slice(0, 30).padEnd(30)} ${new Date(fs.statSync(f).mtimeMs).toISOString().slice(5, 16)} ${String(steps).padStart(5)} ${String(hdrs).padStart(4)}  ${uniq.padEnd(26)} ${String(sysLen).padStart(6)}  ${first}`);
}
