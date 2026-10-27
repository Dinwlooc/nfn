// 上下文文件可信检查：判断上下文里读过的文件是否仍与磁盘一致。
// 用法：node .dsh/trust.mjs [路径...]  无参数时列出本会话读过的文件及状态。
// 输出：每行 <路径>: FRESH|STALE|MISSING|UNSEEN，末行汇总。
// 原理：从当前会话日志取每个文件的最近读取/写入时间，与磁盘 mtime 比较。
// 作者：deepseek-flash ｜2026-10-23
import fs from 'node:fs';
import path from 'node:path';
import zlib from 'node:zlib';

const MAGIC = Buffer.from([0x28, 0xb5, 0x2f, 0xfd]);

function decompressAll(file) {
  const buf = fs.readFileSync(file);
  const positions = [];
  let i = 0;
  while ((i = buf.indexOf(MAGIC, i)) !== -1) { positions.push(i); i += 4; }
  let text = '';
  for (let k = 0; k < positions.length; k++) {
    const start = positions[k];
    const end = k + 1 < positions.length ? positions[k + 1] : buf.length;
    try { text += zlib.zstdDecompressSync(buf.subarray(start, end)).toString('utf8'); } catch { /* frame */ }
  }
  return text;
}

function latestLog() {
  const root = path.join(process.env.DSH_HOME || path.join(process.env.USERPROFILE || '', '.dsh'), 'sessions');
  const want = process.env.DSH_SESSION_ID || '';
  if (want) {
    let hit = '';
    const find = (dir) => {
      let entries = [];
      try { entries = fs.readdirSync(dir, { withFileTypes: true }); } catch { return; }
      for (const entry of entries) {
        if (!entry.isDirectory()) continue;
        const full = path.join(dir, entry.name);
        if (entry.name === want && fs.existsSync(path.join(full, 'session.v4.jsonl.zstd'))) { hit = path.join(full, 'session.v4.jsonl.zstd'); return; }
        find(full);
        if (hit) return;
      }
    };
    find(root);
    if (hit) return hit;
  }
  let best = null;
  const walk = (dir) => {
    let entries = [];
    try { entries = fs.readdirSync(dir, { withFileTypes: true }); } catch { return; }
    for (const entry of entries) {
      const full = path.join(dir, entry.name);
      if (entry.isDirectory()) walk(full);
      else if (entry.name === 'session.v4.jsonl.zstd') {
        const st = fs.statSync(full);
        if (!best || st.mtimeMs > best.mtimeMs) best = { file: full, mtimeMs: st.mtimeMs };
      }
    }
  };
  walk(root);
  return best ? best.file : '';
}

const logFile = process.env.DSH_SESSION_LOG || latestLog();
if (!logFile) { console.log('NO_SESSION_LOG'); process.exit(1); }

const seen = new Map();
for (const line of decompressAll(logFile).split('\n')) {
  if (!line) continue;
  let obj;
  try { obj = JSON.parse(line); } catch { continue; }
  if (obj.type !== 'tool/call') continue;
  const name = obj?.data?.name || '';
  let args = obj?.data?.arguments;
  if (typeof args === 'string') { try { args = JSON.parse(args); } catch { continue; } }
  if (!args || typeof args !== 'object') continue;
  const file = args.file_path || args.path;
  if (!file || typeof file !== 'string') continue;
  if (!['read', 'write', 'edit'].includes(name)) continue;
  const rel = path.resolve(file);
  const prev = seen.get(rel) || { readAt: 0, wroteAt: 0 };
  const t = obj.time || obj.data.time || 0;
  if (name === 'read') prev.readAt = Math.max(prev.readAt, t);
  else prev.wroteAt = Math.max(prev.wroteAt, t);
  seen.set(rel, prev);
}

const paths = process.argv.slice(2).map((p) => path.resolve(p));
const targets = paths.length ? paths : [...seen.keys()].slice(0, 40);

let fresh = 0, stale = 0;
const now = Date.now();
for (const abs of targets) {
  const short = path.relative(process.cwd(), abs) || abs;
  if (!fs.existsSync(abs)) { console.log(`${short}: MISSING`); continue; }
  const record = seen.get(abs);
  if (!record || (!record.readAt && !record.wroteAt)) { console.log(`${short}: UNSEEN`); continue; }
  const base = Math.max(record.readAt, record.wroteAt);
  const mtime = fs.statSync(abs).mtimeMs;
  if (mtime <= base + 1000) { console.log(`${short}: FRESH`); fresh++; }
  else {
    const mins = Math.round((now - base) / 60000);
    console.log(`${short}: STALE (mtime 比读取晚 ${Math.max(1, Math.round((mtime - base) / 1000))}s，读取于 ${mins} 分钟前)`);
    stale++;
  }
}
console.log(`summary: ${targets.length} checked, ${fresh} fresh, ${stale} stale`);
// 作者：deepseek-flash ｜2026-10-23
