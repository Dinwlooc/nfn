#!/usr/bin/env node
/**
 * burn-report.mjs — per-model token-burn rollup (R6 budget-awareness, 0019 era).
 *
 * Joins two read-only sources (writes nothing):
 *   1. $DSH_HOME/budget-watch/<sessionId>.json   — billing ledger (sessionTotal,
 *      cost.billed, task.granted/baseline; 双口径 per AGENTS.md 预算节)
 *   2. $DSH_HOME/storages/session_projcache/sessions/<sessionId>.json
 *      → record.rows.metaToolsModelMap.val.model   (which model ran the session)
 *      → record.rows.tokenUsage.val.totals         (uncachedIn / out / cacheRead /
 *        cacheWrite — the per-model CONSUMPTION HABIT breakdown)
 *
 * Per-model rollup shows that different models burn differently (glm 套餐总量
 * counts cacheRead; deepseek 直计费 counts uncachedIn+out) — the machine basis
 * for the 预算换算 rules each model keeps in its own meta.
 *
 * Usage: node burn-report.mjs [--model <prefix>] [--last <N>]
 *        [--rates "model:type=price,..."]  e.g. "deepseek-flash:uncachedIn=0.27,out=1.15,cacheRead=0.028"
 * Output: one line per model rollup, then `RESULT burn-report: ...`.
 * Exit: 0 always for info lines; 2 on usage error (custom_tools 规范).
 *
 * 折算口径（Owner 更正 2026-10-27）：Deepseek 按 token 计费且**不同类型单价不同**
 * ——billed 原值只是 token 和，跨类型比较必须经 --rates 折算；glm 套餐按总量计，
 * 原值即成本。budget-watch 的 sessionTotal 与 Owner 示数有偏差，Owner 示数为权威。
 */
import { readdir, readFile } from "node:fs/promises";
import { join } from "node:path";
import { existsSync } from "node:fs";

const argv = process.argv.slice(2);
function argOf(name) {
    const i = argv.indexOf(name);
    return i >= 0 ? argv[i + 1] : undefined;
}
if (argv.includes("-h") || argv.includes("--help")) {
    console.log("USAGE burn-report: node burn-report.mjs [--model <prefix>] [--last <N>] [--rates model:type=price,...]");
    process.exit(0);
}
const modelFilter = argOf("--model");
const lastN = Number(argOf("--last") ?? 0);
// --rates "modelA:in=0.27,out=1.15,cacheRead=0.028; modelB:..." → Map<model, Map<type, price>>
const rates = new Map();
const ratesArg = argOf("--rates");
if (ratesArg) {
    for (const part of ratesArg.split(/[;，;]+/u)) {
        const m = /^([^:]+):(.+)$/u.exec(part.trim());
        if (!m) continue;
        const w = new Map();
        for (const kv of m[2].split(",")) {
            const [type, price] = kv.split("=").map((s) => s.trim());
            if (type && price !== undefined && !Number.isNaN(Number(price))) w.set(type, Number(price));
        }
        if (w.size > 0) rates.set(m[1].trim(), w);
    }
}
/** Weighted cost of a habit map under a model's rate table (missing type = 0). */
function costOf(habit, table) {
    if (!table || !habit) return null;
    const map = { uncachedIn: habit.uncachedIn, out: habit.out, cacheRead: habit.cacheRead, cacheWrite: habit.cacheWrite };
    let sum = 0;
    for (const [type, price] of table) sum += (map[type] ?? 0) * price;
    return sum;
}

const home = process.env.DSH_HOME ?? join(process.env.USERPROFILE ?? "", ".dsh");
const ledgerDir = join(home, "budget-watch");
const projDir = join(home, "storages", "session_projcache", "sessions");
if (!existsSync(ledgerDir)) {
    console.log(`ERROR burn-report: no ledger dir ${ledgerDir}`);
    process.exit(1);
}

const ledgers = (await readdir(ledgerDir, { withFileTypes: true }))
    .filter((e) => e.isFile() && e.name.endsWith(".json"))
    .map((e) => e.name);

const rows = [];
for (const name of ledgers) {
    let led;
    try {
        led = JSON.parse(await readFile(join(ledgerDir, name), "utf8"));
    } catch {
        continue;
    }
    const sid = led.sessionId ?? name.replace(/\.json$/, "");
    const billed = (led.cost?.billed ?? 0) + (led.cost?.quota ?? 0);
    const granted = led.task?.granted ?? 0;
    let model = "?";
    let habit = null;
    const projPath = join(projDir, `${sid}.json`);
    if (existsSync(projPath)) {
        try {
            const proj = JSON.parse(await readFile(projPath, "utf8"));
            model = proj?.record?.rows?.metaToolsModelMap?.val?.model ?? "?";
            const t = proj?.record?.rows?.tokenUsage?.val?.totals;
            if (t) {
                habit = {
                    uncachedIn: t.uncachedInputTokens ?? 0,
                    out: t.outputTokens ?? 0,
                    cacheRead: t.cacheReadTokens ?? 0,
                    cacheWrite: t.cacheWriteTokens ?? 0,
                };
            }
        } catch { /* unreadable snapshot: keep ? */ }
    }
    if (modelFilter && !model.startsWith(modelFilter)) continue;
    rows.push({ sid, model, billed, granted, habit, updatedAt: led.updatedAt ?? "" });
}

rows.sort((a, b) => String(a.updatedAt).localeCompare(String(b.updatedAt)));
const picked = lastN > 0 ? rows.slice(-lastN) : rows;

// Per-model rollup: billing total + habit totals. The interesting signal is the
// HABIT MIX (cacheRead share) — glm pays for it, deepseek mostly does not.
const byModel = new Map();
for (const r of picked) {
    const m = byModel.get(r.model) ?? { sessions: 0, billed: 0, granted: 0, uncachedIn: 0, out: 0, cacheRead: 0, cacheWrite: 0 };
    m.sessions++;
    m.billed += r.billed;
    m.granted += r.granted;
    if (r.habit) {
        m.uncachedIn += r.habit.uncachedIn;
        m.out += r.habit.out;
        m.cacheRead += r.habit.cacheRead;
        m.cacheWrite += r.habit.cacheWrite;
    }
    byModel.set(r.model, m);
}
const k = (n) => `${(n / 1000).toFixed(0)}k`;
for (const [model, m] of [...byModel.entries()].sort((a, b) => b[1].billed - a[1].billed)) {
    const total = m.uncachedIn + m.out + m.cacheRead + m.cacheWrite;
    const share = total > 0 ? ` cacheRead=${(100 * m.cacheRead / total).toFixed(0)}%` : "";
    const cost = costOf(m, rates.get(model));
    const costTxt = cost !== null ? ` cost≈${cost.toFixed(0)}` : "";
    console.log(`MODEL ${model} sessions=${m.sessions} billed=${k(m.billed)} granted=${k(m.granted)} | uncachedIn=${k(m.uncachedIn)} out=${k(m.out)} cacheRead=${k(m.cacheRead)}${share}${costTxt}`);
}
for (const r of picked) {
    const h = r.habit ? ` in=${k(r.habit.uncachedIn)} out=${k(r.habit.out)} cr=${k(r.habit.cacheRead)}` : "";
    console.log(`SESSION ${r.sid.slice(0, 13)} model=${r.model} billed=${k(r.billed)} granted=${k(r.granted)}${h}`);
}
console.log(`RESULT burn-report: sessions=${picked.length} models=${byModel.size}${modelFilter ? ` filter=${modelFilter}` : ""}`);
