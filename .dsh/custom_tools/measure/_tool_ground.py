"""Ground a GDScript signal before writing a paradigm annotation.

Why: @emitter / @requester / @signal_listener are a function of who emits and who
listens -- never of style. Guessing the annotation is how a strong (transitive)
annotation ends up poisoning an inheritance chain. Ground first, annotate second.
(Distilled from the render-layer cleanup, 2026-10-17.)

Usage (from repo root, plain python3, stdlib only):
    python _tool_ground.py <SignalName> [root ...]      # default roots: core resource mods

Prints every site as:  <path>:<line>:<kind>: <code>
    declare | emit | connect | disconnect | other
Exit code: 0 if the signal name appears at all, 1 otherwise.
"""
import os
import re
import sys

DEFAULT_ROOTS = ("core", "resource", "mods")
SKIP_DIRS = {".git", ".dsh", "addons", "node_modules", ".godot"}


def walk_gd(roots):
    for root in roots:
        if not os.path.isdir(root):
            continue
        for current, dirs, files in os.walk(root):
            dirs[:] = [d for d in dirs if d not in SKIP_DIRS]
            for name in files:
                if name.endswith(".gd"):
                    yield os.path.join(current, name).replace("\\", "/")


def classify(line, name):
    if re.match(r"^\s*signal\s+%s\b" % re.escape(name), line):
        return "declare"
    if "disconnect(" in line:
        return "disconnect"
    if "connect(" in line:
        return "connect"
    if ".emit(" in line or "emit_signal(" in line:
        return "emit"
    return "other"


def self_test():
    """在 .dsh/.tmp 下建夹具树，验证分类、目录跳过与词边界（不碰真实工作区）。"""
    import io
    import contextlib
    import pathlib
    import shutil

    root = pathlib.Path(__file__).resolve().parents[3]
    tmp = root / ".dsh" / ".tmp" / "ground-fixture"
    shutil.rmtree(tmp, ignore_errors=True)
    (tmp / "core" / "sub").mkdir(parents=True)
    (tmp / "addons" / "vendor").mkdir(parents=True)
    (tmp / "core" / "a.gd").write_text(
        "signal foo_bar_changed\n"
        "@emitter\n"
        "signal foo\n"
        "func go() -> void:\n"
        "\tfoo.emit(1)\n"
        "\tfoo.connect(_on_foo)\n"
        "\tfoo.disconnect(_on_foo)\n"
        "\tvar note := \"foo 只是提到名字\"\n",
        encoding="utf-8",
    )
    (tmp / "core" / "sub" / "b.gd").write_text("func use() -> void:\n\tfoo_bar_changed.emit()\n", encoding="utf-8")
    # 必须被跳过：addons 下的同名信号
    (tmp / "addons" / "vendor" / "c.gd").write_text("signal foo\ntoast.emit()\n", encoding="utf-8")

    def run(name):
        buf = io.StringIO()
        cwd = os.getcwd()
        os.chdir(str(tmp))
        try:
            with contextlib.redirect_stdout(buf):
                code = main(["ground", name])
        finally:
            os.chdir(cwd)
        text = buf.getvalue()
        kinds = {}
        hits = 0
        for line in text.splitlines():
            if line.startswith(("RESULT ground:", "WARN ground:")):
                continue
            hits += 1
            kind = line.split(":", 2)[-1].split(":", 1)[0].strip() if line.count(":") >= 2 else ""
            kinds[kind] = kinds.get(kind, 0) + 1
        return code, kinds, hits

    code_foo, kinds_foo, hits_foo = run("foo")
    code_missing, _, hits_missing = run("nope_missing_signal")

    cases = {
        # foo 命中 5 处：declare / emit / connect / disconnect / 字符串里提到一次（"other"）
        # foo_bar_changed 不该被算进来（词边界），addons 下的同名声明也不该出现（否则 declare=2）
        "bounded_hits=5": hits_foo == 5,
        "declare=1": kinds_foo.get("declare") == 1,
        "emit=1": kinds_foo.get("emit") == 1,
        "connect=1": kinds_foo.get("connect") == 1,
        "disconnect=1": kinds_foo.get("disconnect") == 1,
        "string_mention=other": kinds_foo.get("other") == 1,
        "found_exit=0": code_foo == 0,
        "missing_exit=1": code_missing == 1 and hits_missing == 0,
    }
    bad = 0
    for name, ok in cases.items():
        print("%s fixture %s  (hits=%d kinds=%s)" % ("PASS" if ok else "FAIL", name, hits_foo, kinds_foo))
        bad += 0 if ok else 1
    shutil.rmtree(tmp, ignore_errors=True)
    print("RESULT ground --self-test: cases=%d broken=%d" % (len(cases), bad))
    return 0 if bad == 0 else 1


def main(argv):
    if argv[1:] == ["--self-test"]:
        return self_test()
    if len(argv) < 2:
        print("USAGE ground: python _tool_ground.py <SignalName> [root ...]  (default roots: core resource mods)")
        return 2
    name = argv[1]
    roots = argv[2:] or list(DEFAULT_ROOTS)
    pattern = re.compile(r"\b%s\b" % re.escape(name))
    found = 0
    kinds = {"declare": 0, "emit": 0, "connect": 0, "disconnect": 0, "other": 0}
    for path in walk_gd(roots):
        try:
            with open(path, "r", encoding="utf-8", errors="replace") as handle:
                lines = handle.read().splitlines()
        except OSError:
            continue
        for index, line in enumerate(lines, 1):
            if not pattern.search(line):
                continue
            found += 1
            kind = classify(line, name)
            kinds[kind] = kinds.get(kind, 0) + 1
            print("%s:%d:%s: %s" % (path, index, kind, line.strip()))
    # 有发射端、无 connect 点 = 该信号当前没有消费方（前端未接、或接线被删）
    if found and kinds.get("connect", 0) == 0:
        print("WARN ground: no_connect_site（有声明/发射，但没有任何 connect 点）")
    print("RESULT ground: found=%d%s" % (found, "" if found else " (not found under %s)" % ", ".join(roots)))
    return 0 if found else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
