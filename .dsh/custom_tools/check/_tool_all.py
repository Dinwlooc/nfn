#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""一键收尾校验：把每轮必跑的判据串起来，一条命令给出总账。

覆盖：
  1. `check/_tool_papers.py`     知识库格式 / 基线 sha / 编码损坏 / 索引一致
  2. `check/_tool_refs.py`       命令路径 + 知识库互引的死指针
  3. `measure/_tool_arch_drift.py`  0009 基线与当前扫描是否同步

用法：
  python .dsh/custom_tools/check/_tool_all.py            # 全跑
  python .dsh/custom_tools/check/_tool_all.py --fast     # 跳过漂移（漂移要跑扫描，慢几秒）
  python .dsh/custom_tools/check/_tool_all.py --self-test

退出码：0 全绿 / 1 有失败 / 2 用法错误。
输出：每个判据一行 `OK|FAIL <名字> <RESULT 行>`，末行 `RESULT _tool_all: checks=N failed=M`。
"""
from __future__ import annotations

import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
CHECKS = [
    ("papers", ".dsh/custom_tools/check/_tool_papers.py", []),
    ("refs", ".dsh/custom_tools/check/_tool_refs.py", []),
    ("drift", ".dsh/custom_tools/measure/_tool_arch_drift.py", []),
]


def run_one(name: str, script: str, extra: list[str]) -> tuple[bool, str, str]:
    path = ROOT / script
    if not path.exists():
        return False, name, f"MISSING {script}"
    proc = subprocess.run(
        [sys.executable, str(path), *extra],
        cwd=str(ROOT),
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
    )
    out = (proc.stdout or "") + (proc.stderr or "")
    result_line = ""
    for line in out.splitlines():
        if line.startswith("RESULT "):
            result_line = line.strip()
    ok = proc.returncode == 0
    return ok, name, result_line or (out.strip().splitlines()[-1] if out.strip() else "no output")


def self_test() -> int:
    cases = {}
    ok, name, line = run_one("missing", ".dsh/custom_tools/check/_tool_nope.py", [])
    cases["missing_script=fail"] = (not ok) and name == "missing" and line.startswith("MISSING")
    ok2, _, line2 = run_one("papers", ".dsh/custom_tools/check/_tool_papers.py", ["--self-test"])
    cases["self_test_case_runs"] = ok2 and "self-test" in line2
    bad = 0
    for key, value in cases.items():
        print("%s fixture %s" % ("PASS" if value else "FAIL", key))
        bad += 0 if value else 1
    print("RESULT _tool_all --self-test: cases=%d broken=%d" % (len(cases), bad))
    return 0 if bad == 0 else 1


def main(argv: list[str]) -> int:
    args = argv[1:]
    if args == ["--self-test"]:
        return self_test()
    fast = "--fast" in args
    if args and not fast:
        print("USAGE _tool_all: [--fast] [--self-test]")
        return 2

    selected = [c for c in CHECKS if not (fast and c[0] == "drift")]
    failed = 0
    for name, script, extra in selected:
        ok, label, line = run_one(name, script, extra)
        print("%s %-7s %s" % ("OK  " if ok else "FAIL", label, line))
        failed += 0 if ok else 1
    print("RESULT _tool_all: checks=%d failed=%d fast=%s" % (len(selected), failed, str(fast).lower()))
    return 0 if failed == 0 else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
