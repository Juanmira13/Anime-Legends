"""Type check all Luau code with luau-lsp.

Usage: python tools/typecheck.py

Runs three passes and fails if any reports an error:
  1. Game (src/server, src/client, src/shared) with the game sourcemap.
  2. Island Builder plugin (src/builder) with the plugin sourcemap.
  3. Roblox API pass without a sourcemap. With a sourcemap, luau-lsp types the
     `workspace` and `game` globals loosely, so a wrong property such as
     `workspace.Terrain.Decoration` slips through passes 1 and 2. Without one,
     requires cannot be resolved (that noise is on type 'Instance' and is
     ignored), but properties of Roblox classes are checked strictly.

Environment: ROJO (default "rojo"), LUAU_LSP (default "luau-lsp") and
LUAU_DEFINITIONS (default "globalTypes.d.luau"), see CLAUDE.md section 4.
"""
import os
import pathlib
import subprocess
import sys

PROJECT = pathlib.Path(__file__).resolve().parent.parent
ROJO = os.environ.get("ROJO", "rojo")
LUAU_LSP = os.environ.get("LUAU_LSP", "luau-lsp")
DEFINITIONS = os.environ.get("LUAU_DEFINITIONS", "globalTypes.d.luau")


def run(args: list[str]) -> str:
    result = subprocess.run(args, cwd=PROJECT, capture_output=True, text=True, encoding="utf-8")
    return result.stdout + result.stderr


def errors(output: str) -> list[str]:
    return [line for line in output.splitlines() if "Error:" in line]


def analyze(paths: list[str], sourcemap: str | None) -> str:
    args = [LUAU_LSP, "analyze", "--platform=roblox", f"--definitions={DEFINITIONS}"]
    if sourcemap:
        args.append(f"--sourcemap={sourcemap}")
    return run(args + paths)


def main() -> int:
    if not (PROJECT / DEFINITIONS).is_file():
        # Without Roblox types every pass reports noise or, worse, hides real errors.
        print(f"FAIL: Roblox type definitions not found at '{DEFINITIONS}' (set LUAU_DEFINITIONS)")
        return 1
    run([ROJO, "sourcemap", "default.project.json", "-o", "sourcemap.json"])
    run([ROJO, "sourcemap", "builder.project.json", "-o", "builder-sourcemap.json"])

    passes = {
        "game": errors(analyze(["src/server", "src/client", "src/shared"], "sourcemap.json")),
        "plugin": errors(analyze(["src/builder"], "builder-sourcemap.json")),
        "roblox api": [
            line
            for line in errors(analyze(["src"], None))
            if "not found in external type" in line and "external type 'Instance'" not in line
        ],
    }
    failed = False
    for name, found in passes.items():
        print(f"{'FAIL' if found else 'PASS'} {name}: {len(found)} errors")
        for line in found:
            print(f"  {line}")
        failed = failed or bool(found)
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
