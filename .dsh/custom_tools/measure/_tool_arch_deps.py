# -*- coding: utf-8 -*-
"""L2/L3 架构度量：类间依赖图 → Ce/Ca/I、DIT、A、D(主序列距离)、SCC 环、传播成本、LCOM。
先剥离注释与字符串再取依赖（避免注释提及造成假边）。口径见 0008 v1.1。
用法：python .dsh/public/tools/measure/_tool_arch_deps.py
缓存：.dsh/.arch_deps.json
"""
import os, re, json, collections
import sys

try:  # Windows consoles default to a legacy code page and mangle CJK / crash on arrows
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
except (AttributeError, OSError):
    pass

ROOT = os.getcwd()
SKIP = ("Unused", ".git", ".godot", ".dsh", "addons", ".pytest_cache")
PRE = re.compile(r'preload\(\s*"([^"]+)"\s*\)')
CN = re.compile(r"^\s*class_name\s+(\w+)", re.M)
ABS = re.compile(r"^\s*@abstract", re.M)
IDENT = re.compile(r"\b([A-Z][A-Za-z0-9_]*)\b")


def ind(s):
    return len(s) - len(s.lstrip("\t"))


def strip_code(txt):
    out = []
    for ln in txt.split("\n"):
        buf = []; i = 0; q = None
        while i < len(ln):
            ch = ln[i]
            if q:
                if ch == q: q = None
                i += 1; continue
            if ch in "\"'": q = ch; i += 1; continue
            if ch == "#": break
            buf.append(ch); i += 1
        out.append("".join(buf))
    return "\n".join(out)


def layer(rel):
    for k, v in (("resource/", "resource 面层"), ("core/Class/System/Command/", "System/Command"),
                 ("core/Class/System/Item/", "System/Item"), ("core/Class/System/Manager/", "System/Manager"),
                 ("core/Class/System/Modifier/", "System/Modifier"), ("core/Class/System/Rule/", "System/Rule"),
                 ("core/Class/System/Stage/", "System/Stage"), ("core/Class/System/Trigger/", "System/Trigger"),
                 ("core/Class/System/", "System/其它"), ("core/Class/Render/", "Render"),
                 ("core/Class/Transport/", "Transport"), ("core/Global/", "Global"), ("core/", "core/其它")):
        if rel.startswith(k):
            return v
    return "other"


def scan():
    files = {}
    for dp, dn, fns in os.walk(ROOT):
        dn[:] = [d for d in dn if d not in SKIP]
        for fn in fns:
            if not fn.endswith(".gd"):
                continue
            p = os.path.join(dp, fn)
            rel = os.path.relpath(p, ROOT).replace("\\", "/")
            txt = open(p, encoding="utf-8").read()
            m = CN.search(txt)
            files[rel] = dict(text=txt, code=strip_code(txt), cls=(m.group(1) if m else None))
    return files


def main():
    files = scan()
    by_cls = {v["cls"]: k for k, v in files.items() if v["cls"]}

    def resolve(rel_from, target):
        cand = target[len("res://"):] if target.startswith("res://") else \
            os.path.normpath(os.path.join(os.path.dirname(rel_from), target)).replace("\\", "/")
        return cand if cand in files else None

    deps = collections.defaultdict(set)
    for rel, info in files.items():
        txt, code = info["text"], info["code"]
        for mm in PRE.finditer(txt):
            t = resolve(rel, mm.group(1))
            if t and t != rel:
                deps[rel].add(t)
        em = re.search(r"^extends\s+([A-Za-z_]\w*)", txt, re.M)
        if em and em.group(1) in by_cls and by_cls[em.group(1)] != rel:
            deps[rel].add(by_cls[em.group(1)])
        for mm in IDENT.finditer(code):
            name = mm.group(1)
            if name != info["cls"] and name in by_cls and by_cls[name] != rel:
                deps[rel].add(by_cls[name])

    nodes = sorted(files)
    rev = collections.defaultdict(set)
    for a, bs in deps.items():
        for b in bs:
            rev[b].add(a)
    Ce = {n: len(deps.get(n, ())) for n in nodes}
    Ca = {n: len(rev.get(n, ())) for n in nodes}

    def instab(n):
        c, a = Ce[n], Ca[n]
        return (c / (c + a)) if (c + a) else None

    # SCC
    idx = {}; low = {}; st = []; on = set(); sccs = []; ctr = [0]

    def strong(v):
        idx[v] = low[v] = ctr[0]; ctr[0] += 1
        st.append(v); on.add(v)
        for w in deps.get(v, ()):
            if w not in idx:
                strong(w); low[v] = min(low[v], low[w])
            elif w in on:
                low[v] = min(low[v], idx[w])
        if low[v] == idx[v]:
            comp = []
            while True:
                w = st.pop(); on.discard(w); comp.append(w)
                if w == v: break
            if len(comp) > 1:
                sccs.append(comp)
    for v in nodes:
        if v not in idx:
            strong(v)

    # 传播成本
    reach = 0
    for s in nodes:
        seen = set(); dq = list(deps.get(s, ()))
        while dq:
            x = dq.pop()
            if x in seen:
                continue
            seen.add(x); dq.extend(deps.get(x, ()))
        reach += len(seen)
    n = len(nodes)
    prop = reach / (n * (n - 1)) if n > 1 else 0.0

    # DIT
    def dit(nn):
        d = 0; cur = nn; seen = set()
        while True:
            em = re.search(r"^extends\s+([A-Za-z_]\w*)", files[cur]["text"], re.M)
            if not em or em.group(1) not in by_cls:
                break
            cur = by_cls[em.group(1)]; d += 1
            if cur in seen:
                break
            seen.add(cur)
        return d

    # LCOM（CK）
    lcom = {}
    for rel, info in files.items():
        members = set()
        for ln in info["text"].split("\n"):
            mm = re.match(r"^\t*(?:static\s+)?(?:var|const)\s+(\w+)\s*[:=]", ln)
            if mm:
                members.add(mm.group(1))
        if len(members) < 2:
            continue
        lines = info["code"].split("\n"); ms = []; i = 0
        while i < len(lines):
            m = re.match(r"^(\s*)(?:static\s+)?func\s+[A-Za-z_]\w*", lines[i])
            if not m:
                i += 1; continue
            i0 = len(m.group(1)); b = i + 1
            while b < len(lines):
                if not lines[b].strip():
                    b += 1; continue
                if ind(lines[b]) <= i0:
                    break
                b += 1
            body = "\n".join(lines[i + 1:b])
            used = {x for x in members if re.search(r"\b" + re.escape(x) + r"\b", body)}
            if used:
                ms.append(used)
            i = b
        if len(ms) < 2:
            continue
        P = Q = 0
        for a in range(len(ms)):
            for b2 in range(a + 1, len(ms)):
                if ms[a] & ms[b2]:
                    Q += 1
                else:
                    P += 1
        lcom[rel] = max(0, P - Q)

    lay = collections.defaultdict(list)
    for x in nodes:
        lay[layer(x)].append(x)
    lay_abs = {L: sum(1 for x in ns if ABS.search(files[x]["text"])) for L, ns in lay.items()}

    print("[类型声明网口径 · 真实调用环请跑 _tool_arch_callgraph.py] 文件 %d ｜ 依赖边 %d ｜ 类级环 %d 组（涉及 %d 文件，%.0f%%）｜ 传播成本 %.4f" % (
        n, sum(len(v) for v in deps.values()), len(sccs), sum(len(s) for s in sccs),
        100 * sum(len(s) for s in sccs) / n, prop))
    print("\n%-15s %4s %6s %6s %6s %6s %6s %6s" % ("层", "类", "Ce均", "Ca均", "I", "A", "D", "DIT均"))
    for L, ns in sorted(lay.items(), key=lambda x: -len(x[1])):
        ce = sum(Ce[x] for x in ns) / len(ns); ca = sum(Ca[x] for x in ns) / len(ns)
        iv = [instab(x) for x in ns if instab(x) is not None]
        I = sum(iv) / len(iv) if iv else 0.0
        A = lay_abs[L] / len(ns)
        print("%-15s %4d %6.2f %6.2f %6.2f %6.2f %6.2f %6.2f" % (
            L, len(ns), ce, ca, I, A, abs(A + I - 1), sum(dit(x) for x in ns) / len(ns)))

    edge = collections.Counter()
    for a, bs in deps.items():
        for b in bs:
            if layer(a) != layer(b):
                edge[(layer(a), layer(b))] += 1
    print("\n双向依赖的层对（架构环）：")
    for pair in sorted({frozenset(k) for k in edge if (k[1], k[0]) in edge}):
        a, b = sorted(pair)
        print("  %-15s ↔ %-15s  (%d / %d)" % (a, b, edge.get((a, b), 0), edge.get((b, a), 0)))

    print("\n被依赖最多（Ca Top6，改它最贵）：")
    for k, v in sorted(Ca.items(), key=lambda x: -x[1])[:6]:
        print("  Ca=%2d  %s" % (v, k))
    print("\n内聚最差（LCOM Top6）：")
    for k, v in sorted(lcom.items(), key=lambda x: -x[1])[:6]:
        print("  LCOM=%3d  %s" % (v, k))

    cache = os.path.join(ROOT, ".dsh", ".arch_deps.json")
    json.dump(dict(deps={k: sorted(v) for k, v in deps.items()}, prop=prop,
                   sccs=sccs, lcom=lcom, Ce=Ce, Ca=Ca),
              open(cache, "w", encoding="utf-8"), ensure_ascii=False)
    print("\n-> %s" % cache)
    print("RESULT arch_deps: files=%d edges=%d cycles=%d prop=%.4f" % (
        n, sum(len(v) for v in deps.values()), len(sccs), prop))


if __name__ == "__main__":
    main()
