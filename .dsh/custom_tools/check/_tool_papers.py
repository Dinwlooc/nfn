#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""论文知识库校验器（新格式：标题行 + keywords 行 + 正文；署名由印章 meta_sign 承担）。

判据：
  P1 首行是 `# ` 标题。
  P2 前 5 行内有 `keywords: `（grep 主索引）。
  P3 正文不含旧头部字段块（**模型**/**性质**/**快照**/**版号**/**状态**/**署名** 等）。
  P4 不含文内修订记录段（`**修订记录**` / `## 修订…`）：署名一律走印章。
  P5 README 索引表与磁盘论文一一对应（已清理行除外）。

用法：python .dsh/custom_tools/check/_tool_papers.py [--self-test]
输出：FAIL/WARN 行 + 末行 RESULT；退出码 0 通过 / 1 有违规 / 2 用法错误。
"""
from __future__ import annotations

import contextlib
import io
import re
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
PUBLIC = ROOT / ".dsh" / "public"
INDEX = PUBLIC / "README.md"

PAPER_RE = re.compile(r"^(\d{4})-(.+)\.md$")
OLD_FIELDS = ("模型", "密钥", "性质", "快照", "可信度", "状态", "版号", "关键词", "署名", "基线")
OLD_FIELD_RE = re.compile(r"^\*\*(?:(?:补充|追加|补)?(?:模型|密钥|性质|快照|可信度|状态|版号|关键词|署名|基线)|补充署名|追加署名)\*\*\s*[：:]")
REV_HEAD_RE = re.compile(r"^#{1,3}\s*.*(修订记录|修订日志|修订史|修订 / 推翻|推翻记录|改动记录)")
ROW_RE = re.compile(r"^\|\s*(\d{4})\s*\|")
BASELINE_RE = re.compile(r"^基线[：:]\s*(\S+)")
# 编码损坏特征：替换字符、UTF-8 被当 Latin-1 解出来的典型序列。
# 注意：中文问号"？"与半角"?"在正文里合法，不能拿它当判据（会误杀"怎么算"这类句子）。
MOJIBAKE_RE = re.compile(r"(\ufffd|ï¿½|ðŸ|â€|Ã[\u0080-\u00bf])")


def git_has(base: Path, sha: str) -> bool:
    """提交是否在库里可解析（7–40 hex 前缀即可）。"""
    try:
        out = subprocess.run(
            ["git", "-C", str(base), "cat-file", "-e", f"{sha}^{{commit}}"],
            capture_output=True,
            timeout=10,
        )
    except (OSError, subprocess.SubprocessError):
        return True  # git 不可用时不拦，避免把环境问题当内容问题
    return out.returncode == 0


def check(base: Path, strict: bool = True) -> int:
    public = base / ".dsh" / "public" if (base / ".dsh").is_dir() else base / "public"
    index = public / "README.md"
    fails: list[str] = []
    papers: dict[str, Path] = {}

    for path in sorted(public.rglob("*.md")):
        if path.name.endswith(".revlog.md"):
            continue
        m = PAPER_RE.match(path.name)
        rel = path.relative_to(base).as_posix() if path.is_relative_to(base) else str(path)
        text = path.read_text(encoding="utf-8-sig")
        lines = text.splitlines()

        if m:
            papers[m.group(1)] = path
        elif not (path.parent == public and path.name == "README.md"):
            # 根层知识文件（判定方法 / 工具约束 / 约束 / 元层更新原则…）同受格式约束；README 是索引不算
            pass
        else:
            continue

        if not lines or not lines[0].startswith("# "):
            fails.append(f"FAIL {rel} no_title 首行必须是 '# 标题'")
        if not any(line.startswith("keywords:") for line in lines[:5]):
            fails.append(f"FAIL {rel} no_keywords 前 5 行必须有 'keywords: ...'")
        mojibake = MOJIBAKE_RE.search(text)
        if mojibake:
            line_no = text[: mojibake.start()].count("\n") + 1
            fails.append(f"FAIL {rel}:{line_no} mojibake 检出编码损坏特征：{mojibake.group(0)!r}")
        for i, line in enumerate(lines, 1):
            if OLD_FIELD_RE.match(line):
                fails.append(f"FAIL {rel}:{i} legacy_field 旧头部字段（改用 keywords + 印章）：{line[:40]}")
                break
            if REV_HEAD_RE.match(line):
                fails.append(f"FAIL {rel}:{i} inline_revision 文内修订段（署名走 meta_sign）：{line[:40]}")
                break
            baseline = BASELINE_RE.match(line.strip())
            if baseline:
                value = baseline.group(1)
                if re.match(r"^(n/a|N/A|未记录)", value):
                    continue
                sha = re.match(r"^([0-9a-f]{7,40})", value)
                if not sha:
                    fails.append(f"FAIL {rel}:{i} bad_baseline 基线值不可解析：{value[:24]}")
                elif strict and not git_has(base, sha.group(1)):
                    fails.append(f"FAIL {rel}:{i} baseline_unresolved 基线 {sha.group(1)} 不在 git")

    rows: dict[str, str] = {}
    if index.exists():
        for line in index.read_text(encoding="utf-8-sig").splitlines():
            if not line.strip().startswith("|"):
                continue
            cells = [c.strip() for c in line.strip().strip("|").split("|")]
            if len(cells) >= 4 and re.fullmatch(r"\d{4}", cells[0]):
                rows[cells[0]] = " ".join(cells[3:])
    else:
        fails.append("FAIL .dsh/public/README.md index_missing")
    for num, tail in rows.items():
        if num in papers or re.search(r"清理|丢失|删除", tail):
            continue
        # 0001 是根层通用文件（判定方法.md），不走 NNNN- 命名
        if num == "0001" and (public / "判定方法.md").exists():
            continue
        fails.append(f"FAIL README.md index_orphan 索引 {num} 无对应论文")
    for num in papers:
        if num not in rows:
            fails.append(f"FAIL README.md index_row_missing 论文 {num} 未进索引表")

    for f in fails:
        print(f)
    print(f"RESULT _tool_papers: papers={len(papers)} index_rows={len(rows)} fail={len(fails)}")
    return len(fails)


def _mutate(root: Path, rel: str, old: str, new: str) -> None:
    p = root / "public" / rel
    text = p.read_text(encoding="utf-8-sig")
    if old not in text:
        raise SystemExit(f"fixture target not found: {rel} :: {old}")
    p.write_text(text.replace(old, new, 1), encoding="utf-8")


def self_test() -> int:
    cases = {
        "legacy_field": lambda pub: _mutate(
            pub, "元层/0013-弱模型的可操作性缺口.md", "keywords:", "**模型**：x\n\nkeywords:"),
        "no_keywords": lambda pub: _mutate(
            pub, "元层/0013-弱模型的可操作性缺口.md", "keywords: 弱模型", "note: 弱模型"),
        "index_row_missing": lambda pub: _mutate(
            pub, "README.md", "| 0013 |", "| 0013X |"),
        "baseline_unresolved": lambda pub: _mutate(
            pub, "元层/0022-实验架构-AL1H与AL2H.md", "keywords: AL1H", "基线：deadbee\n\nkeywords: AL1H"),
        "mojibake": lambda pub: _mutate(
            pub, "元层/0022-实验架构-AL1H与AL2H.md", "keywords: AL1H", "keywords: AL1H â€œ编"),
        "supplementary_signature": lambda pub: _mutate(
            pub, "元层/0022-实验架构-AL1H与AL2H.md", "keywords: AL1H", "**补充署名**：某人\n\nkeywords: AL1H"),
    }
    bad = 0
    for name, mutate in cases.items():
        tmp = ROOT / ".dsh" / ".tmp" / "papers-fixture"
        shutil.rmtree(tmp, ignore_errors=True)
        tmp.mkdir(parents=True, exist_ok=True)
        try:
            shutil.copytree(PUBLIC, tmp / "public")
            mutate(tmp)
            with contextlib.redirect_stdout(io.StringIO()):
                f = check(tmp)
            ok = f > 0
            print(f"{'PASS' if ok else 'FAIL'} fixture {name} fail={f}")
            bad += 0 if ok else 1
        finally:
            shutil.rmtree(tmp, ignore_errors=True)
    print(f"RESULT _tool_papers --self-test: cases={len(cases)} broken={bad}")
    return 0 if bad == 0 else 1


def main(argv: list[str]) -> int:
    if argv[1:] == ["--self-test"]:
        return self_test()
    if argv[1:]:
        print("USAGE _tool_papers: python .dsh/custom_tools/check/_tool_papers.py [--self-test]")
        return 2
    return 0 if check(ROOT) == 0 else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
