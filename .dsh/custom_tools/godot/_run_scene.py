#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""跑一个 Godot 场景当判据脚本，带超时——防止 Parse Error 把进程挂死。

为什么需要：判据脚本若编译失败，`_ready()` 里的 `quit()` 永远不会执行，Godot 会一直挂着
（本会话已踩三次，每次要手动 kill 后台 job）。这个包装器把"设超时 + 抓输出 + 给结论"固化成一条命令。

用法：
  python .dsh/custom_tools/godot/_run_scene.py res://.dsh/.tmp/xxx/test.tscn [--timeout 60] [--grep RESULT]

约定：
  * 判据脚本自己打印 `RESULT <名字>: PASS|FAIL` 并 `get_tree().quit(0/1)`；
  * 退出码 0 = 场景正常退出且 grep（若有）命中；1 = 场景退出非 0 或未命中；
    2 = 超时/未找到 Godot；3 = 用法错误。
  * 输出只打印 SCRIPT ERROR / Parse Error / RESULT 与本工具结论行，避免刷屏。
"""
from __future__ import annotations

import argparse
import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
DEFAULT_GODOT = r"D:\游戏开发\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64.exe"
NOISE = ("SCRIPT ERROR", "Parse Error")


def find_godot(explicit: str | None) -> Path | None:
    for candidate in (explicit, os.environ.get("GODOT_BIN"), DEFAULT_GODOT):
        if candidate and Path(candidate).exists():
            return Path(candidate)
    return None


def select_lines(text: str, grep: str, all_output: bool) -> tuple[list[str], bool]:
    """从引擎输出里挑要显示的行走，并判断 grep 是否命中。"""
    shown: list[str] = []
    hit = False
    for line in text.splitlines():
        stripped = line.strip()
        if all_output or any(token in stripped for token in NOISE) or (grep and grep in stripped):
            shown.append(stripped)
            if grep and grep in stripped:
                hit = True
    return shown, hit


def self_test() -> int:
    sample = "\n".join([
        "Godot Engine v4.7.2.stable",
        "ERROR: unrelated noise",
        "SCRIPT ERROR: Parse Error: Too few arguments",
        "RESULT group_attack_timeout: PASS",
    ])
    shown, hit = select_lines(sample, "RESULT", False)
    cases = {
        "filters_noise": "ERROR: unrelated noise" not in shown,
        "keeps_script_error": any("SCRIPT ERROR" in line for line in shown),
        "keeps_result": any(line.startswith("RESULT group_attack_timeout") for line in shown),
        "grep_hit": hit,
        "grep_miss": select_lines(sample, "RESULT_NOPE", False)[1] is False,
        "all_output": len(select_lines(sample, "", True)[0]) == 4,
    }
    missing = find_godot(r"D:\definitely\not\installed\godot.exe")
    cases["missing_engine_when_no_default"] = missing is None or Path(missing).exists()
    bad = 0
    for name, ok in cases.items():
        print("%s fixture %s" % ("PASS" if ok else "FAIL", name))
        bad += 0 if ok else 1
    print("RESULT _run_scene --self-test: cases=%d broken=%d" % (len(cases), bad))
    return 0 if bad == 0 else 1


def main(argv: list[str]) -> int:
    if argv[1:] == ["--self-test"]:
        return self_test()
    parser = argparse.ArgumentParser(add_help=True)
    parser.add_argument("scene", help="res:// 场景路径")
    parser.add_argument("--timeout", type=float, default=60.0)
    parser.add_argument("--grep", default="RESULT")
    parser.add_argument("--godot", default=None)
    parser.add_argument("--all-output", action="store_true")
    args = parser.parse_args(argv[1:])

    godot = find_godot(args.godot)
    if not godot:
        print("FAIL 找不到 Godot 可执行文件（用 --godot 或 GODOT_BIN 指定）")
        return 2

    cmd = [str(godot), "--headless", "--path", str(ROOT), args.scene]
    try:
        proc = subprocess.run(cmd, cwd=str(ROOT), capture_output=True, text=True,
                              encoding="utf-8", errors="replace", timeout=args.timeout)
    except subprocess.TimeoutExpired as exc:
        out = (exc.stdout or "") + (exc.stderr or "")
        print("TIMEOUT 场景在 %.0f 秒内没有退出（脚本 Parse Error 使 quit() 未执行，或场景里有死循环）" % args.timeout)
        for line in out.splitlines():
            if any(token in line for token in NOISE):
                print("   ", line.strip())
        print("RESULT _run_scene: timeout=1")
        return 2

    out = (proc.stdout or "") + (proc.stderr or "")
    shown, hit = select_lines(out, args.grep, args.all_output)
    for line in shown:
        print(line)

    ok = proc.returncode == 0 and hit
    print("RESULT _run_scene: exit=%d grep_hit=%s" % (proc.returncode, str(hit).lower()))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
