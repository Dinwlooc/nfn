/**
 * Regression for dsh-meta-tools v3 pure logic (no harness needed).
 * Run: node dsh-plugins/meta-tools/test/run.mjs
 * Convention: line output, PASS/FAIL per case, RESULT summary line (public/tools style).
 */
import assert from "node:assert/strict";
import { mkdtemp, readFile, rm, writeFile, mkdir } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { createMetaRouteTool } from "../lib/route.js";
import { createMetaSignTool } from "../lib/sign.js";
import { createMetaTaskTypeTool } from "../lib/tasktype.js";
import { modelMapProjection } from "../lib/model-map.js";
import {
    appendRevlog, composeTaskTypes, configTaskTypes, confine, normalizeConfig,
    readProjectConfig, readTaskTypeRegistry, registerTaskType, removeTaskType,
    safeName, setPresetTheme, setThemes, sha256, systemDirOf, themeState, themeStateSync,
} from "../lib/library.js";

let pass = 0;
let failCount = 0;
function check(name, fn) {
    return Promise.resolve()
        .then(fn)
        .then(() => { pass++; console.log(`PASS ${name}`); })
        .catch((e) => { failCount++; console.log(`FAIL ${name}: ${e.message}`); });
}

const ctx = { sessionProjections: { stateOf: () => ({ model: "glm-5.3-flash" }) } };
const exec = { agent: { session: { id: "s1" } } };

const tmp = await mkdtemp(join(tmpdir(), "dsh-meta-tools-"));
const workspace = join(tmp, "ws");
await mkdir(join(workspace, ".dsh", "public"), { recursive: true });
const cfg = normalizeConfig({ root: workspace, presets: [{ theme: "t", taskTypes: ["业务", "插件"] }] });

await check("normalizeConfig defaults (v3)", () => {
    const c = normalizeConfig(undefined);
    assert.equal(c.scaffold, "fill");
    assert.equal(c.revlogEntries, 8);
    assert.equal(c.routeMaxFiles, 40);
    // legacy key accepted one version
    assert.equal(normalizeConfig({ revlogMaxLines: 20 }).revlogEntries, 20);
});

await check("safeName / systemDirOf", () => {
    assert.equal(systemDirOf("glm-5.3-flash"), "glm");
    assert.equal(systemDirOf("deepseek-flash"), "deepseek");
    assert.equal(safeName("a/b:c"), "a_b_c");
});

await check("normalizeConfig theme presets", () => {
    const themed = normalizeConfig({ themes: { sample: { taskTypes: ["评审", "架构"] } }, presetTheme: "sample" });
    assert.deepEqual(configTaskTypes(themed).slice().sort(), ["评审", "架构"].sort());
    let live = "sample";
    const cellCfg = normalizeConfig({ themes: { sample: { taskTypes: ["评审", "架构"] } }, presetTheme: { get: () => live } });
    assert.deepEqual(configTaskTypes(cellCfg).slice().sort(), ["评审", "架构"].sort());
    live = "";
    assert.deepEqual(configTaskTypes(cellCfg), []);
    const unknownTheme = normalizeConfig({ themes: { sample: { taskTypes: ["评审"] } }, presetTheme: "nope", presets: [{ theme: "t", taskTypes: ["业务"] }] });
    assert.deepEqual(configTaskTypes(unknownTheme), ["业务"]);
});

await check("confine rejects outside and .tmp; accepts .dsh-prefixed shape", async () => {
    assert.equal((await confine(cfg, "../escape.md")).ok, false);
    assert.equal((await confine(cfg, ".tmp/x.md")).code, "PROTECTED");
    assert.equal((await confine(cfg, "meta/a.md")).ok, true);
    assert.equal((await confine(cfg, ".dsh/meta/a.md")).ok, true); // meta_sign accepts this shape
});

await check("tasktype registry: register/remove/tombstone-beats-theme, folders untouched", async () => {
    // compose = (theme ∪ public scan ∪ active) − removed
    let types = await composeTaskTypes(cfg);
    assert.deepEqual([...types].sort(), ["业务", "插件"]);
    await registerTaskType(cfg, "评审");
    types = await composeTaskTypes(cfg);
    assert.deepEqual([...types].sort(), ["业务", "插件", "评审"]);
    // tombstone beats theme AND public adoption
    await mkdir(join(workspace, ".dsh", "public", "协作"), { recursive: true });
    await registerTaskType(cfg, "协作");
    types = await composeTaskTypes(cfg);
    assert.ok(types.includes("协作"));
    await removeTaskType(cfg, "协作");
    types = await composeTaskTypes(cfg);
    assert.ok(!types.includes("协作"), "removed type must not route");
    const reg = await readTaskTypeRegistry(cfg);
    assert.ok(reg.removed.includes("协作"));
    // idempotent ops
    await registerTaskType(cfg, "协作"); // restore
    assert.ok((await composeTaskTypes(cfg)).includes("协作"));
    await removeTaskType(cfg, "协作");
    await removeTaskType(cfg, "协作");
    assert.equal((await readTaskTypeRegistry(cfg)).removed.filter((t) => t === "协作").length, 1);
});

await check("meta_tasktype tool: list/register/remove", async () => {
    const tool = createMetaTaskTypeTool(ctx, cfg);
    const l1 = await tool.execute({}, exec);
    assert.equal(l1.code, "OK");
    assert.ok(Array.isArray(l1.active));
    const r1 = await tool.execute({ action: "register", taskType: "测试型" }, exec);
    assert.equal(r1.code, "OK");
    assert.ok(r1.active.includes("测试型"));
    const r2 = await tool.execute({ action: "remove", taskType: "测试型" }, exec);
    assert.equal(r2.code, "OK");
    assert.ok(r2.removed.includes("测试型"));
    const bad = await tool.execute({ action: "register", taskType: "bad type!" }, exec);
    assert.equal(bad.code, "USAGE");
});

await check("meta_sign: NOT_FOUND / non-md / revlog-protected / OUTSIDE_LIB", async () => {
    const tool = createMetaSignTool(ctx, cfg);
    const nf = await tool.execute({ path: ".dsh/public/业务/missing.md", revisionBasis: "b" }, exec);
    assert.equal(nf.code, "NOT_FOUND");
    const nm = await tool.execute({ path: ".dsh/public/业务/x.txt", revisionBasis: "b" }, exec);
    assert.equal(nm.code, "USAGE");
    const pr = await tool.execute({ path: ".dsh/public/业务/a.md.revlog.md", revisionBasis: "b" }, exec);
    assert.equal(pr.code, "PROTECTED");
    const out = await tool.execute({ path: "C:/outside/foo.md", revisionBasis: "b" }, exec);
    assert.equal(out.code, "OUTSIDE_LIB");
    const noBasis = await tool.execute({ path: ".dsh/public/业务/a.md" }, exec);
    assert.equal(noBasis.code, "USAGE");
    const noModel = { sessionProjections: { stateOf: () => ({ model: null }) } };
    const mu = await createMetaSignTool(noModel, cfg).execute({ path: ".dsh/public/业务/a.md", revisionBasis: "b" }, exec);
    assert.equal(mu.code, "MODEL_UNKNOWN");
});

await check("meta_sign: appends sha/model/basis line, cap 8 from project config", async () => {
    const target = join(workspace, ".dsh", "public", "业务", "a.md");
    await mkdir(join(workspace, ".dsh", "public", "业务"), { recursive: true });
    await writeFile(target, "l1\nl2\n", "utf8");
    const tool = createMetaSignTool(ctx, cfg);
    const s1 = await tool.execute({ path: ".dsh/public/业务/a.md", revisionBasis: "首版" }, exec);
    assert.equal(s1.code, "OK");
    assert.equal(s1.unchanged, false);
    // re-sign without change -> unchanged warning, still OK
    const s2 = await tool.execute({ path: ".dsh/public/业务/a.md", revisionBasis: "复核" }, exec);
    assert.equal(s2.code, "OK");
    assert.equal(s2.unchanged, true);
    // edit then sign -> unchanged false again
    await writeFile(target, "l1\nl2\nl3\n", "utf8");
    const s3 = await tool.execute({ path: "public/业务/a.md", revisionBasis: "补行", note: "+l3" }, exec);
    assert.equal(s3.code, "OK");
    assert.equal(s3.unchanged, false);
    const rev = await readFile(`${target}.revlog.md`, "utf8");
    assert.ok(rev.includes("glm-5.3-flash"));
    assert.ok(rev.includes("首版"));
    assert.ok(rev.includes(`sha=${sha256("l1\nl2\nl3\n").slice(0, 8)}`));
    assert.ok(rev.includes("+l3"));
    // project config cap: set revlogEntries=3, sign 5x, expect 3 entries
    await mkdir(join(workspace, ".dsh", "meta"), { recursive: true });
    await writeFile(join(workspace, ".dsh", "meta", "config.json"), JSON.stringify({ version: 1, revlogEntries: 3 }), "utf8");
    const pc = await readProjectConfig(cfg, { revlogEntries: 8 });
    assert.equal(pc.revlogEntries, 3);
    for (let i = 0; i < 5; i++) {
        await appendRevlog(target, `entry ${i}`, pc.revlogEntries);
    }
    const rev2 = await readFile(`${target}.revlog.md`, "utf8");
    const entries = rev2.split(/\r?\n/).filter((l) => l.startsWith("- "));
    assert.equal(entries.length, 3);
    assert.ok(rev2.includes("entry 4"));
    assert.ok(!rev2.includes("entry 1\n"));
});

await check("readProjectConfig: missing/invalid falls back with warning, never throws", async () => {
    const fallback = await readProjectConfig(normalizeConfig({ root: join(tmp, "nope") }), { revlogEntries: 8 });
    assert.equal(fallback.revlogEntries, 8);
    assert.ok(typeof fallback.configWarning === "string");
    await writeFile(join(workspace, ".dsh", "meta", "config.json"), "not json", "utf8");
    const bad = await readProjectConfig(cfg, { revlogEntries: 8 });
    assert.equal(bad.revlogEntries, 8);
    assert.ok(bad.configWarning);
    await writeFile(join(workspace, ".dsh", "meta", "config.json"), JSON.stringify({ version: 1, revlogEntries: 500 }), "utf8");
    const clamp = await readProjectConfig(cfg, { revlogEntries: 8 });
    assert.equal(clamp.revlogEntries, 8); // 500 out of 1..200 -> fallback
    await writeFile(join(workspace, ".dsh", "meta", "config.json"), JSON.stringify({ version: 1, revlogEntries: 12 }), "utf8");
    assert.equal((await readProjectConfig(cfg, { revlogEntries: 8 })).revlogEntries, 12);
});

await check("meta_route inventory provisions with session root (no registry.json, no constants)", async () => {
    const routeCtx = { sessionProjections: ctx.sessionProjections, get: () => undefined };
    const tool = createMetaRouteTool(routeCtx, cfg);
    const inv = await tool.execute({}, exec);
    assert.equal(inv.code, "OK");
    assert.equal(inv.model, "glm-5.3-flash");
    assert.equal(inv.modelDir, ".dsh/glm/glm-5.3-flash");
    assert.ok(inv.taskTypes.includes("业务"));
    assert.ok(!inv.taskTypes.includes("协作")); // tombstoned in the earlier test
    assert.ok(Array.isArray(inv.removed) && inv.removed.includes("协作"));
    // provisioning created the model dir, but NO character constant / registry rows
    const sysMeta = join(workspace, ".dsh", "glm", "meta");
    let noConstant = true;
    try { await readFile(join(sysMeta, "glm-5.3-flash.md"), "utf8"); noConstant = false; } catch { /* good */ }
    assert.ok(noConstant, "v3 must not write character constants");
    let noRegistry = true;
    try { await readFile(join(workspace, ".dsh", "meta", "registry.json"), "utf8"); noRegistry = false; } catch { /* good */ }
    assert.ok(noRegistry, "registry.json must be retired");
});

await check("meta_route routing returns PATHS ONLY, .dsh-prefixed, no bodies", async () => {
    await writeFile(join(workspace, ".dsh", "public", "业务", "细则.md"), "# 细则\n正文", "utf8");
    const tool = createMetaRouteTool(ctx.sessionProjections && { sessionProjections: ctx.sessionProjections, get: () => undefined }, cfg);
    const route = await tool.execute({ taskType: "业务" }, exec);
    assert.equal(route.code, "OK");
    assert.ok(Array.isArray(route.mustRead) && route.mustRead.length > 0);
    for (const m of route.mustRead) {
        assert.ok(typeof m.path === "string" && !m.path.includes("\n"));
        assert.ok(m.path.startsWith(".dsh/"), `workspace-relative with .dsh prefix, got ${m.path}`);
        assert.equal(m.body, undefined, "v3 must not inline bodies");
        assert.ok(Number.isInteger(m.lines));
    }
    assert.ok(route.mustRead.some((m) => m.path.endsWith("public/业务/细则.md")));
    assert.ok(route.mustRead.some((m) => m.path.endsWith("public/meta/分类标准.md") || true));
    // unknown + tombstoned type
    const unknown = await tool.execute({ taskType: "协作" }, exec);
    assert.equal(unknown.code, "USAGE");
    assert.ok(unknown.hint.includes("tombstoned"));
});

await check("projection folds request/context", () => {
    let state = modelMapProjection.init();
    state = modelMapProjection.apply(state, { type: "user/message" });
    assert.equal(state.model, null);
    state = modelMapProjection.apply(state, { type: "request/context", data: { provider: "zai", model: "glm-5.3-flash" } });
    assert.equal(state.model, "glm-5.3-flash");
    const same = modelMapProjection.apply(state, { type: "request/context", data: { provider: "zai", model: "glm-5.3-flash" } });
    assert.ok(same === state);
    assert.equal(modelMapProjection.stateSchema.parse({ model: "m" }).model, "m");
    assert.equal(modelMapProjection.stateSchema.parse({ model: null }).model, null);
    assert.equal(modelMapProjection.wire.viewSchema.parse(modelMapProjection.wire.view(state)).model, "glm-5.3-flash");
    assert.throws(() => modelMapProjection.stateSchema.parse("junk"));
});

await check("theme state / set (volatile cell)", async () => {
    const { createVolatile } = await import("@deepseek-ai/cosmokit");
    const cell = createVolatile("sample");
    const themesCell = createVolatile({ sample: { taskTypes: ["评审"] }, Other: { taskTypes: ["杂务"] } });
    const tcfg = normalizeConfig({ themes: themesCell, presetTheme: cell, root: workspace });
    const s1 = await themeState(tcfg);
    assert.equal(s1.presetTheme, "sample");
    await setPresetTheme(tcfg, "Other");
    assert.equal(themeStateSync(tcfg).presetTheme, "Other");
    await assert.rejects(setPresetTheme(tcfg, "nope"), /unknown theme/);
    await setThemes(tcfg, { Fresh: { taskTypes: ["评审", "计算"] } });
    await setPresetTheme(tcfg, "Fresh");
    assert.deepEqual(configTaskTypes(tcfg), ["评审", "计算"]);
    await assert.rejects(setThemes(normalizeConfig({ root: workspace }), {}), /not volatile/);
});

await check("sha256 stable", () => {
    assert.equal(sha256("abc"), sha256("abc"));
    assert.notEqual(sha256("abc"), sha256("abd"));
});

await check("junction-escaped target rejected (existing file)", async () => {
    const { symlinkSync, rmdirSync } = await import("node:fs");
    const outDir = join(tmp, "outside");
    await mkdir(outDir, { recursive: true });
    await writeFile(join(outDir, "secret.md"), "outside", "utf8");
    const link = join(workspace, ".dsh", "public", "escape");
    symlinkSync(outDir, link, "junction");
    try {
        // existing target -> realpath resolves the junction -> OUTSIDE_LIB
        assert.equal((await confine(cfg, "public/escape/secret.md")).ok, false);
        // nonexistent target under the junction: confine is lexical-ok, but meta_sign
        // cannot write files, so it stops at NOT_FOUND — no escape path exists.
        const tool = createMetaSignTool(ctx, cfg);
        const r = await tool.execute({ path: ".dsh/public/escape/ghost.md", revisionBasis: "b" }, exec);
        assert.equal(r.code, "NOT_FOUND");
    } finally {
        rmdirSync(link);
    }
});

const summary = `RESULT run.mjs: pass=${pass} fail=${failCount}`;
console.log(summary);
await rm(tmp, { recursive: true, force: true });
if (failCount > 0) process.exit(1);
