"""Run every tests/*.spec.luau with the luau CLI.

Usage: python tests/run.py
Set the LUAU environment variable to the luau executable if it is not on PATH.
"""
import os
import pathlib
import subprocess
import sys

from bundle import bundle

PROJECT = pathlib.Path(__file__).resolve().parent.parent
ROOTS = {
    "Shared": PROJECT / "src" / "shared",
    "Server": PROJECT / "src" / "server",
    "Client": PROJECT / "src" / "client",
}
LUAU = os.environ.get("LUAU", "luau")


def main() -> int:
    failed = []
    for spec in sorted((PROJECT / "tests").glob("*.spec.luau")):
        out = PROJECT / "build" / "tests" / spec.name
        bundle(ROOTS, spec, out)
        result = subprocess.run([LUAU, str(out)], capture_output=True, text=True, encoding="utf-8")
        output = (result.stdout + result.stderr).strip()
        status = "PASS" if result.returncode == 0 else "FAIL"
        print(f"{status} {spec.name}: {output}")
        if result.returncode != 0:
            failed.append(spec.name)
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
