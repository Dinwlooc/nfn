# -*- coding: utf-8 -*-
"""区分三种依赖图，回答"环依赖从哪来"：
  type  — 类型声明网：类型标注 / 常量与静态引用 / 信号与方法签名参数 / is 检查
  call  — 调用网：extends + 显式类静态调用 + 实例化（不含变量上的实例方法调用）
  call2 — 调用网 v2：call + 按声明类型推断出的实例方法调用（x.m()，x: Type）
用法：python .dsh/public/tools/measure/_tool_arch_callgraph.py
口径见 0007 v3.0；数字进 0009。
"""
import os, re, json, collections
import sys

try:  # Windows consoles default to a legacy code page and mangle CJK
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
except (AttributeError, OSError):
    pass

ROOT = os.getcwd()
SKIP = ("Unused", ".git", ".godot", ".dsh", "addons", ".pytest_cache")
CN = re.compile(r"^\s*class_name\s+(\w+)", re.M)
IDENT = re.compile(r"\b([A-Z][A-Za-z0-9_]*)\b")

files = {}
for dp, dn, fns in os.walk(ROOT):
    dn[:] = [d for d in dn if d not in SKIP]
    for fn in fns:
        if not fn.endswith(".gd"):
            continue
        p = os.path.join(dp, fn)
        rel = os.path.relpath(p, ROOT).replace("\\", "/")
        t = open(p, encoding="utf-8").read()
        m = CN.search(t)
        files[rel] = dict(text=t, cls=(m.group(1) if m else None))
by_cls = {v["cls"]: k for k, v in files.items() if v["cls"]}


def build(mode):
    g = collections.defaultdict(set)
    for rel, info in files.items():
        own = info["cls"]; varmap = {}
        for ln in info["text"].split("\n"):
            raw = "" if ln.strip().startswith("#") else ln.split("#")[0]
            for pm2 in re.finditer(r'preload\(\s*"([^"]+)"', raw):
                tp = pm2.group(1)
                tgt = None
                if tp.startswith("res://"):
                    tgt = tp[len("res://"):]
                else:
                    tgt = os.path.normpath(os.path.join(os.path.dirname(rel), tp)).replace("\\", "/")
                if tgt in files and tgt != rel:
                    g[rel].add(tgt)
            mm = re.match(r"^\s*extends\s+([A-Za-z_]\w*)", raw)
            if mm and mm.group(1) in by_cls and by_cls[mm.group(1)] != rel:
                g[rel].add(by_cls[mm.group(1)])
            for vm in re.finditer(r"\b([a-zA-Z_]\w*)\s*:\s*([A-Z][A-Za-z0-9_]*)\b", raw):
                varmap[vm.group(1)] = vm.group(2)
            for tok in IDENT.findall(raw):
                if tok == own or tok not in by_cls:
                    continue
                tgt = by_cls[tok]
                if tgt == rel:
                    continue
                is_call = re.search(tok + r"\.\w+\s*\(", raw) is not None
                is_new = re.search(tok + r"\.new\s*\(", raw) is not None
                if mode == "type":
                    if re.search(r":\s*" + tok + r"\b", raw) or is_call or is_new or \
                       re.search(r"\bis\s+" + tok, raw):
                        g[rel].add(tgt)
                else:
                    if is_call or is_new:
                        g[rel].add(tgt)
            if mode == "call2":
                for cm in re.finditer(r"\b([a-zA-Z_]\w*)\s*\.\s*([a-zA-Z_]\w*)\s*\(", raw):
                    t = varmap.get(cm.group(1))
                    if t and t in by_cls and by_cls[t] != rel:
                        g[rel].add(by_cls[t])
    return g


def stats(g):
    nodes = sorted(set(g) | {x for s in g.values() for x in s})
    idx = {}; low = {}; st = []; on = set(); sccs = []; ctr = [0]

    def strong(v):
        idx[v] = low[v] = ctr[0]; ctr[0] += 1; st.append(v); on.add(v)
        for w in g.get(v, ()):
            if w not in idx:
                strong(w); low[v] = min(low[v], low[w])
            elif w in on:
                low[v] = min(low[v], idx[w])
        if low[v] == idx[v]:
            comp = []
            while True:
                w = st.pop(); on.discard(w); comp.append(w)
                if w == v:
                    break
            if len(comp) > 1:
                sccs.append(comp)
    for v in nodes:
        if v not in idx:
            strong(v)
    reach = 0
    for s in nodes:
        seen = set(); dq = list(g.get(s, ()))
        while dq:
            x = dq.pop()
            if x in seen:
                continue
            seen.add(x); dq.extend(g.get(x, ()))
        reach += len(seen)
    n = len(nodes)
    return nodes, sccs, (reach / (n * (n - 1)) if n > 1 else 0.0)


print("%-6s %5s %6s %6s %8s %8s  %s" % ("图", "节点", "边", "SCC组", "环内文件", "占比", "传播成本"))
res = {}
for mode, name in (("type", "类型声明网"), ("call", "调用网(不含实例调用)"), ("call2", "调用网(含实例调用)")):
    g = build(mode); nodes, sccs, prop = stats(g)
    tot = sum(len(s) for s in sccs); res[mode] = (g, sccs, prop, nodes)
    print("%-6s %5d %6d %6d %8d %7.0f%%  %.4f" % (
        name, len(nodes), sum(len(v) for v in g.values()), len(sccs), tot, 100 * tot / len(nodes), prop))

print("\n类型声明网里的环（来源=签名与常量引用）：")
for s in sorted(res["type"][1], key=len, reverse=True):
    print("  [%2d] %s" % (len(s), ", ".join(os.path.basename(x) for x in s[:7])))

print("\n调用网 v2 里的环（来源=真实调用）：")
for s in sorted(res["call2"][1], key=len, reverse=True):
    print("  [%2d] %s" % (len(s), ", ".join(os.path.basename(x) for x in s[:7])))

json.dump({m: {k: sorted(v) for k, v in res[m][0].items()} for m in res},
          open(os.path.join(ROOT, ".dsh", ".arch_callgraph.json"), "w", encoding="utf-8"),
          ensure_ascii=False)
print("\n-> .dsh/.arch_callgraph.json")
print("RESULT arch_callgraph: type_nodes=%d type_cycles=%d call2_nodes=%d call2_cycles=%d" % (
    len(res["type"][3]), len(res["type"][1]), len(res["call2"][3]), len(res["call2"][1])))
