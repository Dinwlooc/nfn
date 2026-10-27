#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""命令路径校验器：md 里"可执行命令"引用的文件是否还存在。

只看含 `python/node/git/dsh` 的命令行——那是读者会照抄的指令，行内代码也算；
论文正文里的历史路径（如已删除的 legacy-route）不算违规。

判据：
  R1 命令行里形如 `.dsh/...`、`res://...`、`core/...`、`public/...` 的路径必须存在。
  R2 `python .dsh/a.py` / `node .dsh/b.mjs` 的目标脚本必须存在。
  R3 行内 `<占位符>` 与含 `*`、`...` 的路径跳过（不是可执行引用）。
  R4 行内代码里的**知识库互引**（反引号包住、以 `.md` 结尾且含 `/`）必须能找到：
     依次在「仓库根 / .dsh / 本文所在目录 / .dsh/deepseek/deepseek-flash」下解析。

用法：python .dsh/custom_tools/check/_tool_refs.py [--self-test]
输出：DEAD <file>:<line> <path>；末行 RESULT；退出码 0 通过 / 1 有死指针 / 2 用法错误。
"""
from __future__ import annotations

import contextlib
import io
import re
import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
DSH = ROOT / ".dsh"
SKIP_PARTS = {".tmp", "corrupt"}

FENCE_RE = re.compile(r"^\s*```")
CMD_RE = re.compile(r"^\s*(python|node|git|dsh|python3)\b")
TOKEN_RE = re.compile(r"(?<![\w`/])((?:\.dsh|core|public|custom_tools)/[^\s`'\"）)，,；;]+|res://[^\s`'\"）)，,；;]+)")


def collect_md(base: Path, skip_tmp: bool = True) -> list[Path]:
    out = []
    for p in sorted(base.rglob("*.md")):
        if p.name.endswith(".revlog.md"):
            continue  # 印章日志是历史快照，不追改指向
        if skip_tmp and SKIP_PARTS & set(p.parts):
            continue
        out.append(p)
    return out


def exists_project(token: str) -> bool:
    if token.startswith("res://"):
        return (ROOT / token[len("res://"):]).exists()
    cand = [ROOT / token, DSH / token]
    return any(c.exists() for c in cand)


MD_INLINE_RE = re.compile(r"`([^`\n]+)`")


def md_ref_bases(md: Path) -> list[Path]:
    """知识库互引的解析基准：仓库根 → .dsh → 本文所在目录 → 默认模型记忆库。"""
    return [ROOT, DSH, DSH / "public", md.parent, DSH / "deepseek" / "deepseek-flash"]


def exists_md_ref(token: str, md: Path) -> bool:
    if token.startswith("res://"):
        return (ROOT / token[len("res://"):]).exists()
    return any((base / token).exists() for base in md_ref_bases(md))


def check(base: Path, skip_tmp: bool = True) -> int:
    dead = 0
    checked = 0
    mds = collect_md(base, skip_tmp)
    for md in mds:
        in_fence = False
        for i, line in enumerate(md.read_text(encoding="utf-8-sig").splitlines(), 1):
            if FENCE_RE.match(line):
                in_fence = not in_fence
                continue
            if in_fence:
                # 代码块里的行仍要查命令路径，只是不查知识库互引
                pass
            # R4：反引号里的知识库互引（含 / 且以 .md 结尾）
            # 只查 public/ 知识库：私人记忆与 experiments/ 归档是历史记录，不追改指向
            if not in_fence and (base / "public") in md.parents:
                for inline in MD_INLINE_RE.findall(line):
                    tok = inline.strip()
                    if "/" not in tok or not tok.endswith(".md"):
                        continue
                    if any(c in tok for c in "*<>…") or tok.startswith(("http", "res://")):
                        continue
                    if "NNNN" in tok or "标题" in tok:
                        continue  # 命名模板，不是真实文件
                    checked += 1
                    if not exists_md_ref(tok, md):
                        rel = md.relative_to(ROOT).as_posix() if md.is_relative_to(ROOT) else str(md)
                        print(f"DEAD {rel}:{i} {tok}")
                        dead += 1
            if not CMD_RE.search(line) and not re.search(r"`(?:python|node)\s", line):
                continue
            for token in TOKEN_RE.findall(line):
                tok = token.rstrip(".")
                if any(c in tok for c in "*<>…") or tok.endswith("..."):
                    continue
                if "." not in tok.rsplit("/", 1)[-1]:
                    continue  # 末尾无扩展名：多为运行时输出目录，不是静态引用
                checked += 1
                if not exists_project(tok):
                    rel = md.relative_to(ROOT).as_posix() if md.is_relative_to(ROOT) else str(md)
                    print(f"DEAD {rel}:{i} {tok}")
                    dead += 1
    print(f"RESULT _tool_refs: files={len(mds)} refs={checked} dead={dead}")
    return 0 if dead == 0 else 1


def self_test() -> int:
    bad = 0
    tmp = ROOT / ".dsh" / ".tmp" / "refs-fixture"
    cases = {
        "dead_script": ("python .dsh/custom_tools/nope/_tool_x.py", 1),
        "live_script": ("python .dsh/custom_tools/check/_tool_papers.py", 0),
        "dead_res": ("node res://core/nope.js", 1),
        "dead_md_ref": ("见 `元层/9999-不存在的论文.md`", 1),
        "live_md_ref": ("见 `元层/0022-实验架构-AL1H与AL2H.md`", 0),
    }
    for name, (cmd, want) in cases.items():
        shutil.rmtree(tmp, ignore_errors=True)
        (tmp / "public").mkdir(parents=True, exist_ok=True)
        # 含反引号的互引用例写成普通段落，命令用例写在围栏里（围栏行不查互引）
        body = f"{cmd}\n" if "`" in cmd else f"```\n{cmd}\n```\n"
        (tmp / "public" / "t.md").write_text(body, encoding="utf-8")
        buf = io.StringIO()
        with contextlib.redirect_stdout(buf):
            got = check(tmp, skip_tmp=False)
        ok = (got == 1) == (want == 1)
        print(f"{'PASS' if ok else 'FAIL'} fixture {name} dead={got}")
        bad += 0 if ok else 1
    shutil.rmtree(tmp, ignore_errors=True)
    print(f"RESULT _tool_refs --self-test: cases={len(cases)} broken={bad}")
    return 0 if bad == 0 else 1


def main(argv: list[str]) -> int:
    if argv[1:] == ["--self-test"]:
        return self_test()
    if argv[1:]:
        print("USAGE _tool_refs: python .dsh/custom_tools/check/_tool_refs.py [--self-test]")
        return 2
    return check(DSH)


if __name__ == "__main__":
    sys.exit(main(sys.argv))
