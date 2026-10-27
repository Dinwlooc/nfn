"""Shape check -- did a change touch only comments and ordering?

Verdicts (ASCII, because console code pages mangle CJK):
    SAME            file is unchanged from HEAD
    COMMENTS-ONLY   changed, but the multiset of non-comment lines is identical
                    (comments, section banners, blank lines, moved blocks)
    CODE-DIFF +N/-M non-comment lines added/removed -> a human must look;
                    behavioural changes hide here

Why three verdicts and not two: a cross-vendor reader saw "CLEAN" next to files that
`git diff --numstat` reported as +34/-15 and concluded the tool was lying. The tool's
judgement was right (the metric is non-comment lines), but the label invited the
opposite reading -- a judgement that cannot be misread is part of the judgement.
The same misreading caught the author's own hand-rolled check, which counted
section banners (`#==vars==`) as code because it dropped the first character of every
line instead of testing the whole line for the comment prefix.

Usage (from repo root, stdlib only):
    python _tool_shape.py [path ...]        # default: `git diff --name-only` + 未跟踪文件
    python _tool_shape.py --self-test       # 临时仓库里的五条夹具
Exit code: 0 when nothing is CODE-DIFF, 1 otherwise.
"""
import collections
import subprocess
import sys

COMMENT_PREFIX = "#"
SAMPLE = 5

try:  # Windows consoles mangle CJK; force UTF-8 on the way out
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
except (AttributeError, OSError):
    pass


def git(*args):
    return subprocess.run(["git", *args], capture_output=True)


def head_text(path):
    proc = git("show", "HEAD:" + path)
    if proc.returncode != 0:
        return None
    return proc.stdout.decode("utf-8", "replace")


def code_lines(text):
    counter = collections.Counter()
    for raw in text.splitlines():
        stripped = raw.strip()
        if not stripped or stripped.startswith(COMMENT_PREFIX):
            continue
        counter[stripped] += 1
    return counter


def unchanged(path):
    return git("diff", "--quiet", "HEAD", "--", path).returncode == 0


def changed_files():
    # HEAD, not the index: staged changes (git add) must count as changed too.
    tracked = [line.strip() for line in git("diff", "HEAD", "--name-only").stdout.decode("utf-8", "replace").splitlines()
               if line.strip()]
    # 未跟踪的新文件不在 diff 里，但它们同样是"改动"——漏掉会把新增代码判成"没有改动"
    untracked = [line.strip() for line in git("ls-files", "--others", "--exclude-standard").stdout.decode("utf-8", "replace").splitlines()
                 if line.strip()]
    return tracked + untracked


def self_test():
    """在 .dsh/.tmp 下建临时 git 仓库，验证四种判定的边界（不碰真实工作区）。

    覆盖的坑：
      * 注释/节标题（`#==vars==`）改动必须判 COMMENTS-ONLY，不能算代码；
      * 未跟踪的新 .gd 文件判 CODE-DIFF（"全是新增"）；
      * 未修改的 .gd 判 SAME；
      * 非 .gd 判 SKIP。
    """
    import contextlib
    import io
    import os
    import pathlib
    import shutil

    root = pathlib.Path(__file__).resolve().parents[3]
    tmp = root / ".dsh" / ".tmp" / "shape-fixture"
    shutil.rmtree(tmp, ignore_errors=True)
    tmp.mkdir(parents=True, exist_ok=True)

    def run_git(*args):
        return subprocess.run(["git", *args], cwd=str(tmp), capture_output=True)

    run_git("init")
    run_git("config", "user.email", "t@example.com")
    run_git("config", "user.name", "t")
    (tmp / "code.gd").write_text("func a():\n\tpass\n", encoding="utf-8")
    (tmp / "comment_only.gd").write_text("func b():\n\tpass\n#==vars==\n", encoding="utf-8")
    (tmp / "sections.gd").write_text("#==vars==\nfunc c():\n\tpass\n", encoding="utf-8")
    (tmp / "same.gd").write_text("func s():\n\tpass\n", encoding="utf-8")
    (tmp / "notes.txt").write_text("x\n", encoding="utf-8")
    run_git("add", "-A")
    run_git("commit", "-m", "base")

    # 制造四类改动 + 一个未跟踪新文件
    (tmp / "comment_only.gd").write_text("func b():\n\tpass\n# 只改了注释\n", encoding="utf-8")
    (tmp / "sections.gd").write_text("#==new===\nfunc c():\n\tpass\n", encoding="utf-8")
    (tmp / "code.gd").write_text("func a():\n\treturn 1\n", encoding="utf-8")
    (tmp / "new.gd").write_text("func d():\n\tpass\n", encoding="utf-8")

    def verdicts(argv):
        buf = io.StringIO()
        old = os.getcwd()
        os.chdir(str(tmp))
        try:
            with contextlib.redirect_stdout(buf):
                code = main(argv)
        finally:
            os.chdir(old)
        text = buf.getvalue()
        result = {}
        for line in text.splitlines():
            if line.startswith("RESULT shape:"):
                for pair in line.split(":", 1)[1].split():
                    key, _, value = pair.partition("=")
                    result[key] = int(value)
        return code, result

    code_changed, counts_changed = verdicts(["shape"])
    code_same, counts_same = verdicts(["shape", "same.gd"])
    code_skip, counts_skip = verdicts(["shape", "notes.txt"])

    cases = {
        "comment_and_banner=COMMENTS-ONLY": counts_changed.get("COMMENTS-ONLY") == 2,
        "code_and_untracked=CODE-DIFF": counts_changed.get("CODE-DIFF") == 2,
        "changed_exit=1": code_changed == 1,
        "same=SAME": counts_same.get("SAME") == 1 and code_same == 0,
        "non_gd=SKIP": counts_skip.get("SKIP") == 1,
    }
    bad = 0
    for name, ok in cases.items():
        print("%s fixture %s  (changed=%s same=%s skip=%s)" % (
            "PASS" if ok else "FAIL", name, counts_changed, counts_same, counts_skip))
        bad += 0 if ok else 1
    shutil.rmtree(tmp, ignore_errors=True)
    print("RESULT shape --self-test: cases=%d broken=%d" % (len(cases), bad))
    return 0 if bad == 0 else 1


def main(argv):
    if argv[1:] == ["--self-test"]:
        return self_test()
    verbose = "-v" in argv
    files = [arg for arg in argv[1:] if arg != "-v"] or changed_files()
    if not files:
        print("RESULT shape: files=0")
        return 0
    counts = collections.Counter()
    failures = 0

    def emit(verdict, message):
        counts[verdict] += 1
        print("%-13s %s" % (verdict, message))

    for path in files:
        if not path.endswith(".gd"):
            emit("SKIP", "%s (not .gd)" % path)
            continue
        # 先判"HEAD 里有没有"：未跟踪文件在 `git diff --quiet` 下也算无差异，会被误判成 SAME
        old_text = head_text(path)
        if old_text is None:
            emit("CODE-DIFF", "%s (untracked: everything is new)" % path)
            failures += 1
            continue
        if unchanged(path):
            emit("SAME", path)
            continue
        try:
            with open(path, "r", encoding="utf-8", errors="replace") as handle:
                new_text = handle.read()
        except OSError as error:
            emit("ERROR", "%s: %s" % (path, error))
            failures += 1
            continue
        old_lines, new_lines = code_lines(old_text), code_lines(new_text)
        if old_lines == new_lines:
            emit("COMMENTS-ONLY", "%s  (%d code lines identical)" % (path, sum(old_lines.values())))
            continue
        failures += 1
        removed, added = old_lines - new_lines, new_lines - old_lines
        emit("CODE-DIFF", "%s  (+%d / -%d code lines)" % (path, sum(added.values()), sum(removed.values())))
        if verbose:
            for line in list(removed)[:SAMPLE]:
                print("   - %s" % line)
            for line in list(added)[:SAMPLE]:
                print("   + %s" % line)
    summary = " ".join("%s=%d" % (key, counts[key]) for key in ("CODE-DIFF", "COMMENTS-ONLY", "SAME", "SKIP", "ERROR"))
    print("RESULT shape: %s" % summary)
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
