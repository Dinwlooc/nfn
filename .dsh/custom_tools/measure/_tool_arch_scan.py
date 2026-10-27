# -*- coding: utf-8 -*-
"""架构指标扫描器：以方法为分母，注解为标签，方法体为独立证据。
输出 .dsh/.arch_cache.json，供 _tool_arch_report.py 出表。

口径要点（见 .dsh/public/架构/0007）：
- 成员作用域：只认类体缩进层级的 var/const，方法内局部 var 不算成员。
- 叶子方法（leaf）：方法体不调用本文件内其他方法；@atomic 定义为叶子形式（owner 定义）。
- 静态方法：无实例状态，恒计入安全性；但"是否原子"由叶子形式决定，不由 static 推出。
"""
import os, re, sys, json

try:  # Windows consoles default to a legacy code page and mangle CJK
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
except (AttributeError, OSError):
    pass

ROOT = os.getcwd()
SKIP = ("Unused", ".git", ".godot", ".dsh", "addons", ".pytest_cache")
ANN = re.compile(r"@([a-z_][a-z0-9_]*)")
BRANCH = re.compile(r"\b(if|elif|for|while|match)\b")
LIFECYCLE = {"_ready", "_process", "_physics_process", "_input", "_unhandled_input", "_draw",
             "_init", "_notification", "_enter_tree", "_exit_tree", "_gui_input",
             "_unhandled_key_input"}
MUT_CALL = re.compile(r"\b(emit|add_child|queue_free|connect|disconnect|append|erase|clear|merge|"
                      r"insert|remove_at|set_shader_parameter|tween_property|call_deferred)\s*\(")
CALL = re.compile(r"\b(?:self\.)?([A-Za-z_]\w*)\s*\(")


def ind(s):
    return len(s) - len(s.lstrip("\t"))


def layer(rel):
    for k, v in (("resource/", "resource 面层"), ("core/Class/System/Command/", "System/Command"),
                 ("core/Class/System/Item/", "System/Item"),
                 ("core/Class/System/Manager/", "System/Manager"),
                 ("core/Class/System/Modifier/", "System/Modifier"),
                 ("core/Class/System/Rule/", "System/Rule"),
                 ("core/Class/System/Stage/", "System/Stage"),
                 ("core/Class/System/Trigger/", "System/Trigger"),
                 ("core/Class/System/", "System/其它"), ("core/Class/Render/", "Render"),
                 ("core/Class/Transport/", "Transport"), ("core/Global/", "Global"),
                 ("core/", "core/其它")):
        if rel.startswith(k):
            return v
    return "other"


def parse(path):
    rel = os.path.relpath(path, ROOT).replace("\\", "/")
    lines = open(path, encoding="utf-8").read().split("\n")
    # 本文件方法名表（叶子判定用）
    names = set()
    for ln in lines:
        nm = re.match(r"^\s*(?:static\s+)?func\s+([A-Za-z_]\w*)\s*\(", ln)
        if nm:
            names.add(nm.group(1))
    # 成员：只认类体缩进层级
    members = set()
    body_inds = {0}
    for ln in lines:
        cm = re.match(r"^(\t*)class\s+\w+", ln)
        if cm:
            body_inds.add(len(cm.group(1)) + 1)
    for ln in lines:
        mm = re.match(r"^(\t*)(?:static\s+)?(?:var|const)\s+(\w+)\s*[:=]", ln)
        if mm and len(mm.group(1)) in body_inds:
            members.add(mm.group(2))
    out = []
    i = 0
    while i < len(lines):
        m = re.match(r"^(\s*)(static\s+)?func\s+([A-Za-z_]\w*)\s*\(", lines[i])
        if not m:
            i += 1
            continue
        ind0 = len(m.group(1)); static = bool(m.group(2)); name = m.group(3)
        j = i
        bal = lines[i].count("(") - lines[i].count(")")
        while bal > 0 and j + 1 < len(lines):
            j += 1
            bal += lines[j].count("(") - lines[j].count(")")
        sig = " ".join(x.strip() for x in lines[i:j + 1])
        anns = set(); k = i - 1; doc = False
        while k >= 0 and lines[k].strip().startswith("#"):
            if lines[k].strip().startswith("##"):
                doc = True
            anns |= set(ANN.findall(lines[k])); k -= 1
        b = j + 1
        while b < len(lines):
            if not lines[b].strip():
                b += 1; continue
            if ind(lines[b]) <= ind0:
                break
            b += 1
        body = "\n".join(lines[j + 1:b])
        pm = re.search(r"\((.*)\)", sig); params = []
        if pm:
            for raw in pm.group(1).split(","):
                pn = raw.split(":")[0].split("=")[0].strip()
                if re.match(r"^[A-Za-z_]\w*$", pn):
                    params.append(pn)
        own = 0; extr = 0
        for a in re.finditer(r"(?m)^\s*([A-Za-z_]\w*(?:\.[A-Za-z_]\w*)?)\s*(?:[+\-*/%]?=)", body):
            base = a.group(1).split(".")[0]
            if base == "self" or base in members:
                own += 1
            elif base in params:
                extr += 1
        if re.search(r"\bself\.[A-Za-z_]\w*\s*(?:[+\-*/%]?=)", body):
            own += 1
        calls = set()
        for cm in CALL.finditer(body):
            if cm.group(1) in names and cm.group(1) != name:
                calls.add(cm.group(1))
        leaf = not calls
        if static:
            if anns & {"override", "hook"}:
                kind = "hook"
            elif "factory" in anns:
                kind = "factory"
            elif anns & {"pure", "nullable_pure"}:
                kind = "pure_static"
            elif "atomic" in anns:
                kind = "atomic"
            elif "delegates" in anns:
                kind = "delegates"
            else:
                kind = "static_other"
        elif anns & {"pure", "nullable_pure"}:
            kind = "pure"
        elif "atomic" in anns:
            kind = "atomic"
        elif "external" in anns:
            kind = "external"
        elif "internal" in anns:
            kind = "internal"
        elif "delegates" in anns:
            kind = "delegates"
        elif "operation" in anns:
            kind = "operation"
        elif "facade" in anns:
            kind = "facade"
        elif "side_effect" in anns:
            kind = "side_effect"
        elif anns & {"hook", "override", "template", "chain_override"}:
            kind = "hook"
        elif own and extr:
            kind = "un_both"
        elif own:
            kind = "un_own"
        elif extr:
            kind = "un_ext"
        elif MUT_CALL.search(body):
            kind = "un_call"
        else:
            kind = "un_read"
        out.append(dict(rel=rel, layer=layer(rel), name=name, static=static, leaf=leaf,
                        private=name.startswith("_"), lifecycle=name in LIFECYCLE,
                        kind=kind, doc=doc, ann=bool(anns), params=len(params),
                        branches=len(BRANCH.findall(body))))
        i = b
    return out


def main():
    recs = []
    for dp, dn, fns in os.walk(ROOT):
        dn[:] = [d for d in dn if d not in SKIP]
        for fn in fns:
            if fn.endswith(".gd"):
                recs += parse(os.path.join(dp, fn))
    cache = os.path.join(ROOT, ".dsh", ".arch_cache.json")
    json.dump(recs, open(cache, "w", encoding="utf-8"), ensure_ascii=False)
    ms = [r for r in recs if not r["lifecycle"]]
    print("RESULT arch_scan: files=%d methods=%d non_lifecycle=%d static=%d leaf=%d leaf_pct=%.1f cache=%s" % (
        len({r["rel"] for r in recs}), len(recs), len(ms),
        sum(1 for r in ms if r["static"]), sum(1 for r in ms if r["leaf"]),
        100 * sum(1 for r in ms if r["leaf"]) / len(ms), cache))


if __name__ == "__main__":
    main()
