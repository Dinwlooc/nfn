#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""架构基线漂移巡检：把 `0009` 里"已知漂移"那行的实测数字与当前工作区的扫描结果比对。

背景：`0009` 的数字是某个提交/工作区状态的快照，代码一动就落后。手写提醒不可靠，
所以让机器每次读一遍：

  python .dsh/custom_tools/measure/_tool_arch_drift.py            # 只检查
  python .dsh/custom_tools/measure/_tool_arch_drift.py --update   # 漂移则改写 0009 的那一行

退出码：0 一致 / 1 有漂移（未 --update）/ 2 用法或解析失败。
输出：`DRIFT <键> 文档=<a> 实测=<b>`；末行 RESULT。
"""
from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
SCAN = ROOT / ".dsh" / "custom_tools" / "measure" / "_tool_arch_scan.py"
DOC = ROOT / ".dsh" / "public" / "架构" / "0009-架构指标基线.md"

KEYS = ("files", "methods", "non_lifecycle", "static", "leaf", "leaf_pct")
RESULT_RE = re.compile(r"RESULT arch_scan: (.+)")
DOC_LINE_RE = re.compile(r"^(\d+\.\s*\*\*已知漂移\*\*.*)$", re.MULTILINE)
NUM_RE = re.compile(r"(files|methods|non_lifecycle|static|leaf|leaf_pct)=([0-9.]+)")


def scan_now() -> dict[str, str]:
    proc = subprocess.run(
        [sys.executable, str(SCAN)],
        cwd=str(ROOT),
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
    )
    out = (proc.stdout or "") + (proc.stderr or "")
    for line in out.splitlines():
        m = RESULT_RE.search(line)
        if m:
            return {k: v for k, v in NUM_RE.findall(m.group(1))}
    print("FAIL 扫描器没有输出 RESULT 行")
    raise SystemExit(2)


def doc_numbers(text: str) -> tuple[dict[str, str], str]:
    m = DOC_LINE_RE.search(text)
    if not m:
        print("FAIL 0009 里找不到「已知漂移」行")
        raise SystemExit(2)
    line = m.group(1)
    nums = {k: v for k, v in NUM_RE.findall(line)}
    # 只取"当前工作区实测为 …"之后的部分，避免把其它历史数字算进来
    tail = line.split("当前工作区实测为", 1)[-1]
    return {k: v for k, v in NUM_RE.findall(tail)}, line


def render_line(line: str, now: dict[str, str]) -> str:
    head = line.split("当前工作区实测为", 1)[0].rstrip()
    if head.endswith("）"):
        head = head[:-1]  # 旧行在"当前工作区实测为"前已有一个右括号
    body = " / ".join(f"{k}={now[k]}" for k in KEYS if k in now)
    return (
        f"{head}当前工作区实测为 `{body}`**（2026-10-27 复跑）。"
        "重跑工具后数字会小幅上移，引用前请以工具输出为准，不要直接引用本表。"
    )


def self_test() -> int:
    """不跑扫描，只验证"解析—渲染—再解析"这条链不丢数字。"""
    sample = (
        "9. **已知漂移**：本文件表格是快照。**当前工作区实测为 "
        "`files=1 / methods=2 / non_lifecycle=3 / static=4 / leaf=5 / leaf_pct=6.6`**（旧）。"
    )
    nums, line = doc_numbers(sample)
    want = {"files": "1", "methods": "2", "non_lifecycle": "3", "static": "4", "leaf": "5", "leaf_pct": "6.6"}
    ok_parse = nums == want
    rendered = render_line(line, {"files": "9", "methods": "8", "non_lifecycle": "7", "static": "6", "leaf": "5", "leaf_pct": "4.4"})
    again, _ = doc_numbers(rendered)
    ok_render = again.get("files") == "9" and again.get("leaf_pct") == "4.4" and "））。" not in rendered
    print(f"parse={ok_parse} render={ok_render} rendered_has_double_paren={'））。' in rendered}")
    print(f"RESULT _tool_arch_drift --self-test: {'PASS' if ok_parse and ok_render else 'FAIL'}")
    return 0 if ok_parse and ok_render else 1


def main(argv: list[str]) -> int:
    if argv[1:] == ["--self-test"]:
        return self_test()
    update = "--update" in argv[1:]
    if argv[1:] and not update:
        print("USAGE _tool_arch_drift: [--update]")
        return 2
    text = DOC.read_text(encoding="utf-8")
    doc_nums, line = doc_numbers(text)
    now = scan_now()
    diffs = [(k, doc_nums.get(k), now.get(k)) for k in KEYS if doc_nums.get(k) != now.get(k)]
    if not diffs:
        print("RESULT _tool_arch_drift: drift=0 " + " ".join(f"{k}={now.get(k)}" for k in KEYS))
        return 0
    for k, a, b in diffs:
        print(f"DRIFT {k} 文档={a} 实测={b}")
    if update:
        new_line = render_line(line, now)
        DOC.write_text(text.replace(line, new_line, 1), encoding="utf-8")
        print("UPDATED 0009 已知漂移行")
        print("RESULT _tool_arch_drift: drift=%d updated=1" % len(diffs))
        return 0
    print("RESULT _tool_arch_drift: drift=%d updated=0" % len(diffs))
    return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
