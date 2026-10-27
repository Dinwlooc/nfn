# -*- coding: utf-8 -*-
"""架构指标报表：读 .dsh/.arch_cache.json，输出分层指标与方法台账。
口径见 .dsh/public/架构/0007。"""
import os, json, collections
import sys

try:  # Windows consoles default to a legacy code page and mangle CJK
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
except (AttributeError, OSError):
    pass

ROOT = os.getcwd()
recs = json.load(open(os.path.join(ROOT, ".dsh", ".arch_cache.json"), encoding="utf-8"))
ms = [r for r in recs if not r["lifecycle"]]
PURE = {"pure", "pure_static"}
SAFE_INST = {"external", "internal"}
RISK = {"un_own", "un_ext", "un_both"}
READ = {"un_read"}
LBL = {"pure": "@pure 纯函数(实例)", "pure_static": "@pure 纯函数(静态)",
       "factory": "@factory 静态工厂", "atomic": "@atomic 原子业务(已标)",
       "static_other": "静态·未标", "external": "@external 外生",
       "internal": "@internal 内生", "side_effect": "@side_effect 副作用",
       "delegates": "@delegates 委托", "operation": "@operation 操作",
       "facade": "@facade 门面", "hook": "@hook/@override 钩子重写",
       "un_both": "未标·改自身+参数", "un_own": "未标·改自身", "un_ext": "未标·改参数",
       "un_call": "未标·仅调用", "un_read": "未标·无写入"}


def agg(rows):
    n = len(rows)
    st = sum(1 for r in rows if r["static"])
    priv = sum(1 for r in rows if r["private"])
    leaf = sum(1 for r in rows if r["leaf"])
    safe = st + sum(1 for r in rows if (not r["static"]) and r["kind"] in PURE | SAFE_INST | READ)
    risk = sum(1 for r in rows if r["kind"] in RISK)
    nocall = sum(1 for r in rows if r["kind"] == "un_call")
    exp = sum(1 for r in rows if r["static"] and not r["private"]) + \
        sum(1 for r in rows if (not r["static"]) and (not r["private"]) and r["kind"] == "pure")
    pub_leaf = sum(1 for r in rows if r["leaf"] and not r["private"])
    return dict(n=n, st=st / n, encap=priv / n, safe=safe / n, risk=risk / n,
                comp=1 - (risk + nocall) / n, exp=exp, expd=exp / n,
                leaf=leaf / n, pub_leaf=pub_leaf,
                atom=sum(r["branches"] for r in rows) / n,
                par=sum(r["params"] for r in rows) / n)


def main():
    byl = collections.defaultdict(list); byc = collections.defaultdict(list)
    for r in ms:
        byl[r["layer"]].append(r); byc[r["rel"]].append(r)

    print("=== 表1 分层架构指标（分母=非生命周期方法 %d）===" % len(ms))
    print("%-15s %5s %6s %6s %6s %6s %6s %7s %6s %6s %6s" %
          ("层", "方法", "静态率", "叶子率", "封装度", "安全性", "风险率", "复用密度", "完整度", "原子度", "参数均"))
    order = sorted(byl.items(), key=lambda x: -len(x[1]))
    for L, rows in order:
        d = agg(rows)
        print("%-15s %5d %5.1f%% %5.1f%% %6.2f %6.2f %6.2f %6.1f%% %6.2f %6.2f %6.2f" % (
            L, d["n"], 100 * d["st"], 100 * d["leaf"], d["encap"], d["safe"], d["risk"],
            100 * d["expd"], d["comp"], d["atom"], d["par"]))
    d = agg(ms)
    print("%-15s %5d %5.1f%% %5.1f%% %6.2f %6.2f %6.2f %6.1f%% %6.2f %6.2f %6.2f" % (
        "合计", d["n"], 100 * d["st"], 100 * d["leaf"], d["encap"], d["safe"], d["risk"],
        100 * d["expd"], d["comp"], d["atom"], d["par"]))

    print("\n=== 表2 导出复用价值 Top 12（公开静态 + 公开纯实例）===")
    print("%-58s %-10s %4s %6s %6s %7s" % ("类", "层", "方法", "导出", "密度", "公开叶子"))
    for rel, d in sorted([(r, agg(v)) for r, v in byc.items()],
                         key=lambda x: (-x[1]["exp"], -x[1]["expd"]))[:12]:
        print("%-58s %-10s %4d %6d %5.1f%% %7d" % (rel, byc[rel][0]["layer"], d["n"], d["exp"],
                                                   100 * d["expd"], d["pub_leaf"]))

    print("\n=== 表3 未声明写状态风险 Top 10 ===")
    print("%-58s %-10s %4s %7s %7s" % ("类", "层", "方法", "风险率", "风险数"))
    cand = [(r, agg(v)) for r, v in byc.items() if agg(v)["risk"] > 0]
    for rel, d in sorted(cand, key=lambda x: -(x[1]["risk"] * x[1]["n"]))[:10]:
        print("%-58s %-10s %4d %6.1f%% %7d" % (rel, byc[rel][0]["layer"], d["n"],
                                               100 * d["risk"], round(d["risk"] * d["n"])))

    print("\n=== 表4 @atomic 台账（按 owner 定义：叶子形式）===")
    rec_atomic = [r for r in ms if r["kind"] == "atomic"]
    stat_atomic = [r for r in ms if r["static"] and r["kind"] == "atomic"]
    all_atomic = [r for r in ms if r["kind"] == "atomic"]
    print("  已标 @atomic：%d（静态 %d ／ 实例 %d）" % (
        len(all_atomic), len(stat_atomic), len(all_atomic) - len(stat_atomic)))
    print("  叶子 %d ／ 非叶子 %d（越标已清零，见 0007 v1.3 §八）" % (
        sum(1 for r in all_atomic if r["leaf"]), sum(1 for r in all_atomic if not r["leaf"])))

    print("\n=== 表5 方法级范式台账 ===")
    c = collections.Counter(r["kind"] for r in ms)
    for k, v in c.most_common():
        print("  %-26s %5d  %5.1f%%" % (LBL.get(k, k), v, 100 * v / len(ms)))


    # 表6/7 需要依赖数据（Ce/Ca/LCOM），来自 _tool_arch_deps.py 的缓存
    deps_path = os.path.join(ROOT, ".dsh", ".arch_deps.json")
    Ce, Ca, lcom = {}, {}, {}
    if os.path.exists(deps_path):
        _dj = json.load(open(deps_path, encoding="utf-8"))
        Ce, Ca, lcom = _dj.get("Ce", {}), _dj.get("Ca", {}), _dj.get("lcom", {})
    else:
        print("\n[提示] 未找到 .dsh/.arch_deps.json，表6/7 的 Ce/Ca/LCOM 为空；先跑 _tool_arch_deps.py")

    # ---- 表6 实体类 vs 数据类（数据类按类名后缀判定） ----
    import re as _re
    DATA = _re.compile(r"(Data|Pack|Config|Constants)$")
    def cls_of(rel):
        path = os.path.join(ROOT, rel)
        try:
            t = open(path, encoding="utf-8").read()
        except OSError:
            return os.path.basename(rel)[:-3]
        m = _re.search(r"^\s*class_name\s+(\w+)", t, _re.M)
        return m.group(1) if m else os.path.basename(rel)[:-3]

    grp = collections.defaultdict(list)
    for rel, rows in byc.items():
        grp["数据类" if DATA.search(cls_of(rel)) else "实体类"].append((rel, rows))
    print("\n=== 表6 实体类 vs 数据类（层均值会被实体类支配，须分开读）===")
    print("%-8s %5s %6s %6s %7s %7s %7s" % ("组", "类", "方法", "叶子率", "静态率", "LCOM均", "Ca均"))
    for g in ("实体类", "数据类"):
        if not grp[g]:
            continue
        allrows = [r for _, rows in grp[g] for r in rows]
        d = agg(allrows)
        lc = [lcom[r] for r, rows in grp[g] if r in lcom and len(rows) >= 5]
        ca = [Ca.get(r, 0) for r, _ in grp[g]]
        print("%-8s %5d %6d %5.1f%% %5.1f%% %7.1f %7.1f" % (
            g, len(grp[g]), d["n"], 100 * d["leaf"], 100 * d["st"],
            (sum(lc) / len(lc)) if lc else 0.0, sum(ca) / len(ca) if ca else 0.0))
    print("  注：LCOM 仅对实体类且方法数≥5 的类统计（数据类无状态可共享，读数无意义）。")

    # ---- 表7 System/Item 按类拆分 ----
    print("\n=== 表7 System/Item 层按类拆分 ===")
    print("%-12s %-6s %4s %6s %5s %5s %5s %7s" % ("类", "类型", "方法", "叶子", "Ce", "Ca", "LCOM", "已注解"))
    item_rows = [(rel, rows) for rel, rows in byc.items() if rel.startswith("core/Class/System/Item/")]
    for rel, rows in sorted(item_rows, key=lambda x: -len(x[1])):
        nm = cls_of(rel)
        d = agg(rows)
        print("%-12s %-6s %4d %6d %5d %5d %5s %7d" % (
            nm, "数据类" if DATA.search(nm) else "实体类", d["n"],
            sum(1 for r in rows if r["leaf"]), Ce.get(rel, 0), Ca.get(rel, 0),
            lcom.get(rel, "-"), sum(1 for r in rows if r["ann"])))

    print("RESULT arch_report: methods=%d classes=%d leaf_pct=%.1f" % (
        len(ms), len({r["rel"] for r in ms}), 100 * sum(1 for r in ms if r["leaf"]) / len(ms)))


if __name__ == "__main__":
    main()
