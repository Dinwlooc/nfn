#!/usr/bin/env node
// DSH plugin-market explorer: merges the profile's market indexes, caches them,
// and prints compact rows so a model can survey the ecosystem for a few k tokens.
// usage:
//   node market.mjs search <term...> [--limit N] [--cat c] [--index u] [--fresh]
//   node market.mjs show <name>
//   node market.mjs stats
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';

const CACHE = path.join(os.tmpdir(), 'dsh-market');
const TTL = 12 * 3600 * 1000;
const INDEXES = [
  'https://dshopen.org/index.json',
  'https://raw.githubusercontent.com/vlln/plugin-registry/main/index.json',
  'https://cdn.jsdelivr.net/npm/dsh-plugin-catalog/index.json',
  'https://nwasvsad.github.io/dsh-plugin-market/index.json',
];

const args = process.argv.slice(2);
const cmd = args.shift() || 'stats';
const flags = new Map();
const terms = [];
for (let i = 0; i < args.length; i++) {
  const a = args[i];
  if (a === '--fresh') flags.set('fresh', true);
  else if (a === '--limit') flags.set('limit', Number(args[++i]) || 20);
  else if (a === '--cat') flags.set('cat', String(args[++i] || '').toLowerCase());
  else if (a === '--index') flags.set('index', String(args[++i] || ''));
  else terms.push(a);
}

const cachePath = (u) => path.join(CACHE, Buffer.from(u).toString('base64url') + '.json');
async function loadIndex(u) {
  fs.mkdirSync(CACHE, { recursive: true });
  const f = cachePath(u);
  const fresh = flags.get('fresh');
  try {
    const st = fs.statSync(f);
    if (!fresh && Date.now() - st.mtimeMs < TTL) return JSON.parse(fs.readFileSync(f, 'utf8'));
  } catch {}
  try {
    const r = await fetch(u, { signal: AbortSignal.timeout(40000) });
    if (!r.ok) throw new Error('status ' + r.status);
    const j = await r.json();
    fs.writeFileSync(f, JSON.stringify(j));
    return j;
  } catch (e) {
    try { return JSON.parse(fs.readFileSync(f, 'utf8')); } catch {}
    console.error('warn: ' + u + ' -> ' + e.message);
    return null;
  }
}

const txt = (v) => (typeof v === 'string' ? v : v ? v.en || v.zh || Object.values(v)[0] || '' : '');
const oneLine = (s) => String(s || '').replace(/\s+/g, ' ').trim();
function latest(versions) {
  if (!Array.isArray(versions) || !versions.length) return null;
  return versions[versions.length - 1];
}
const stars = (e) => Number(e.metadata?.sortKeys?.['github-stars'] || 0);
const labels = (e) => (e.metadata?.labels || []).join(',');

const all = new Map();
const loaded = [];
for (const u of INDEXES) {
  const j = await loadIndex(u);
  if (!j) continue;
  const list = Array.isArray(j) ? j : j.plugins || j.entries || [];
  loaded.push([u, list.length]);
  for (const e of list) {
    if (!e?.name) continue;
    const prev = all.get(e.name);
    if (prev && stars(prev) >= stars(e)) continue;
    all.set(e.name, { ...e, _index: u });
  }
}

if (cmd === 'stats') {
  for (const [u, n] of loaded) console.log(`${n}\t${u}`);
  console.log(`total ${all.size} unique plugins`);
  const cats = new Map();
  for (const e of all.values()) {
    const c = e.metadata?.category || '(none)';
    cats.set(c, (cats.get(c) || 0) + 1);
  }
  console.log('categories: ' + [...cats].sort((a, b) => b[1] - a[1]).map(([c, n]) => `${c}:${n}`).join(' '));
  process.exit(0);
}

if (cmd === 'show') {
  const name = terms[0];
  const e = all.get(name);
  if (!e) {
    console.log('not found: ' + name);
    process.exit(2);
  }
  const v = latest(e.versions);
  console.log(`name: ${e.name}`);
  console.log(`title: ${oneLine(txt(e.title))}`);
  console.log(`category: ${e.metadata?.category || '-'}  labels: ${labels(e) || '-'}  stars: ${stars(e)}`);
  console.log(`version: ${v?.version || '-'}  published: ${v?.publishTimestamp ? new Date(v.publishTimestamp * 1000).toISOString().slice(0, 10) : '-'}`);
  console.log(`engines: ${JSON.stringify(v?.engines || {})}`);
  console.log(`repo: ${e.repository?.url || e.homepage || '-'}`);
  console.log(`desc: ${oneLine(txt(e.description))}`);
  console.log(`versions: ${(e.versions || []).map((x) => x.version).join(' ') || '-'}`);
  process.exit(0);
}

const kw = terms.map((t) => t.toLowerCase());
const cat = flags.get('cat');
const hits = [];
for (const e of all.values()) {
  if (cat && String(e.metadata?.category || '').toLowerCase() !== cat) continue;
  const hay = [e.name, txt(e.title), txt(e.description), (e.metadata?.keywords || []).join(' '), e.metadata?.category]
    .join(' ')
    .toLowerCase();
  if (!kw.every((k) => hay.includes(k))) continue;
  hits.push(e);
}
hits.sort((a, b) => stars(b) - stars(a) || String(a.name).localeCompare(String(b.name)));
const limit = flags.get('limit') || 20;
for (const e of hits.slice(0, limit)) {
  const v = latest(e.versions);
  const eng = v?.engines?.dsh ? ' [dsh ' + v.engines.dsh + ']' : '';
  console.log(
    `${e.name}@${v?.version || '?'}${eng} | ★${stars(e)} | ${e.metadata?.category || '-'} | ${oneLine(txt(e.title)).slice(0, 40)} :: ${oneLine(txt(e.description)).slice(0, 110)}`
  );
}
console.log(`-- ${hits.length} hits (showing ${Math.min(limit, hits.length)}) of ${all.size}`);
