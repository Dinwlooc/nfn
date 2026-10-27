#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""budget-watch 分账汇总：把每个会话/子代理的 ledger 按模型汇总成 ¥ 与 token。

原来只能手工翻 `$DSH_HOME/budget-watch/*.json`；本工具一次跑出：
  - 按模型的 hit / miss / out token 与折价（¥/M 三档）
  - 按会话的花费排行（含子代理会话）
  - 总计 ¥ 与总 token

用法：
  python .dsh/custom_tools/tools/_tool_budget.py [--top N] [--dir <ledger 目录>] [--json] [--self-test]

价格默认取 budget-watch 插件当前展示价（2026-10-27）；可用 --prices 指向 JSON 覆盖：
  {"deepseek-flash": {"hit": 0.043, "miss": 2.13, "out": 8.52}, ...}
未在价格表中的模型（如 glm 订阅套餐）只统计 token，不计入 ¥。
"""
from __future__ import annotations

import argparse
import json
import os
import sys
import tempfile
from pathlib import Path

DEFAULT_PRICES = {
    "deepseek-flash": {"hit": 0.043, "miss": 2.13, "out": 8.52},
    "deepseek-v4-pro": {"hit": 0.31, "miss": 9.37, "out": 28.12},
}


def ledger_dir(explicit: str | None) -> Path:
    if explicit:
        return Path(explicit)
    home = os.environ.get("DSH_HOME") or str(Path.home() / ".dsh")
    return Path(home) / "budget-watch"


def load_entries(directory: Path) -> list[dict]:
    entries = []
    for path in sorted(directory.glob("*.json")):
        if path.name == "probe.json":
            continue
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            continue
        if not isinstance(data, dict) or "models" not in data:
            continue
        data["_file"] = path.name
        entries.append(data)
    return entries


def cost_of(model: str, usage: dict, prices: dict) -> float:
    table = prices.get(model)
    if not table:
        return 0.0
    return (
        usage.get("hit", 0) * table["hit"]
        + usage.get("miss", 0) * table["miss"]
        + usage.get("out", 0) * table["out"]
    ) / 1_000_000


def summarize(entries: list[dict], prices: dict) -> tuple[dict, list[tuple[str, float, dict]]]:
    per_model: dict[str, dict] = {}
    rows = []
    for entry in entries:
        session_cost = 0.0
        for model, usage in entry.get("models", {}).items():
            if not isinstance(usage, dict):
                continue
            agg = per_model.setdefault(
                model, {"hit": 0, "miss": 0, "out": 0, "write": 0, "cost": 0.0, "sessions": 0}
            )
            for key in ("hit", "miss", "out", "write"):
                agg[key] += int(usage.get(key, 0) or 0)
            c = cost_of(model, usage, prices)
            agg["cost"] += c
            agg["sessions"] += 1
            session_cost += c
        rows.append((entry.get("sessionId") or entry.get("_file"), session_cost, entry.get("models", {})))
    rows.sort(key=lambda r: r[1], reverse=True)
    return per_model, rows


def render(per_model: dict, rows: list[tuple], top: int) -> str:
    out = []
    total_cost = sum(m["cost"] for m in per_model.values())
    total_tok = sum(m["hit"] + m["miss"] + m["out"] for m in per_model.values())
    out.append(f"{'模型':<20}{'hit':>12}{'miss':>10}{'out':>10}{'¥':>10}  会话数")
    for model in sorted(per_model, key=lambda k: per_model[k]["cost"], reverse=True):
        m = per_model[model]
        out.append(f"{model:<20}{m['hit']:>12}{m['miss']:>10}{m['out']:>10}{m['cost']:>10.2f}  {m['sessions']}")
    out.append(f"{'合计':<20}{'':>12}{'':>10}{total_tok:>10}{total_cost:>10.2f}")
    out.append("")
    out.append(f"花费最高的 {min(top, len(rows))} 个会话：")
    for session, cost, models in rows[:top]:
        who = ",".join(models.keys())
        out.append(f"  ¥{cost:>7.2f}  {session}  [{who}]")
    return "\n".join(out)


def self_test() -> int:
    # 沙箱下系统临时目录不可写，夹具放工程内 .dsh/.tmp，跑完即删
    import shutil

    root = Path(__file__).resolve().parents[3]
    tmp = root / ".dsh" / ".tmp" / "budget-fixture"
    shutil.rmtree(tmp, ignore_errors=True)
    tmp.mkdir(parents=True, exist_ok=True)
    try:
        d = tmp
        (d / "a.json").write_text(json.dumps({
            "sessionId": "s1", "models": {
                "deepseek-flash": {"hit": 1_000_000, "miss": 1_000_000, "out": 1_000_000}}}), encoding="utf-8")
        (d / "b.json").write_text(json.dumps({
            "sessionId": "s2", "models": {
                "deepseek-v4-pro": {"hit": 1_000_000, "miss": 1_000_000, "out": 1_000_000}}}), encoding="utf-8")
        (d / "probe.json").write_text("{}", encoding="utf-8")
        entries = load_entries(d)
        per_model, rows = summarize(entries, DEFAULT_PRICES)
        flash = per_model["deepseek-flash"]["cost"]
        pro = per_model["deepseek-v4-pro"]["cost"]
        ok = abs(flash - (0.043 + 2.13 + 8.52)) < 1e-6 and abs(pro - (0.31 + 9.37 + 28.12)) < 1e-6
        print(f"fixture entries={len(entries)} flash=¥{flash:.2f} pro=¥{pro:.2f}")
        print(f"RESULT _tool_budget --self-test: {'PASS' if ok else 'FAIL'}")
        return 0 if ok else 1
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(add_help=True)
    parser.add_argument("--top", type=int, default=10)
    parser.add_argument("--dir")
    parser.add_argument("--prices")
    parser.add_argument("--json", action="store_true")
    parser.add_argument("--self-test", action="store_true")
    parser.add_argument("--match", help="只统计 sessionId 或文件名包含该子串的 ledger（例如 session-6e3e 或子代理 id）")
    parser.add_argument("--stop", type=float, help="停线金额（¥）：按账本合计给出剩余额度与百分比")
    args = parser.parse_args(argv[1:])
    if args.self_test:
        return self_test()

    prices = dict(DEFAULT_PRICES)
    if args.prices:
        try:
            prices.update(json.loads(Path(args.prices).read_text(encoding="utf-8")))
        except (OSError, json.JSONDecodeError) as exc:
            print(f"FAIL 价格文件不可读：{exc}")
            return 2

    directory = ledger_dir(args.dir)
    if not directory.is_dir():
        print(f"FAIL ledger 目录不存在：{directory}")
        return 2
    entries = load_entries(directory)
    if args.match:
        needle = args.match.lower()
        entries = [
            e for e in entries
            if needle in str(e.get("sessionId", "")).lower() or needle in e["_file"].lower()
        ]
        if not entries:
            print(f"FAIL 没有匹配 {args.match} 的 ledger")
            return 2
    per_model, rows = summarize(entries, prices)
    if args.json:
        print(json.dumps({"per_model": per_model, "total": sum(m["cost"] for m in per_model.values())},
                         ensure_ascii=False, indent=2))
        return 0
    print(render(per_model, rows, args.top))
    total = sum(m["cost"] for m in per_model.values())
    if args.stop:
        # 停线口径：账本合计（含子代理与其它会话），不是"本会话"——Owner 的预算对整项工作生效
        left = args.stop - total
        pct = 100.0 * total / args.stop if args.stop else 0.0
        print(f"STOP total=¥{total:.2f} line=¥{args.stop:.2f} left=¥{left:.2f} used={pct:.1f}%")
        if left <= 0:
            print("STOP 已超额：停止工作并向 Owner 报告")
        elif pct >= 80:
            print("STOP 已过 80%：优先收尾与交接，不再开新方向")
    print(f"RESULT _tool_budget: sessions={len(entries)} models={len(per_model)}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
