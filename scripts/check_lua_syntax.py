#!/usr/bin/env python3
"""Best-effort Lua syntax validation for this repository.

Validation order:
1) `luac -p` if available
2) `lua` (loadfile) if available
3) `luajit` (loadfile) if available
4) Python `luaparser` if installed

If no validator is available, the script prints a warning and exits 0 so CI/dev flows
can continue without hard-failing on missing optional tooling.
"""
from __future__ import annotations

import shutil
import subprocess
import sys
from pathlib import Path


def iter_lua_files(paths: list[str]) -> list[Path]:
    if paths:
        return [Path(p) for p in paths]

    return sorted(Path('.').glob('*.lua')) + sorted(Path('bridge').glob('*.lua'))


def run_cmd(cmd: list[str]) -> tuple[int, str]:
    proc = subprocess.run(cmd, capture_output=True, text=True)
    output = (proc.stdout or '') + (proc.stderr or '')
    return proc.returncode, output.strip()


def validate_with_luac(file: Path) -> tuple[bool, str]:
    code, out = run_cmd(['luac', '-p', str(file)])
    return code == 0, out


def validate_with_loadfile(runtime: str, file: Path) -> tuple[bool, str]:
    code, out = run_cmd([runtime, '-e', f"assert(loadfile('{file.as_posix()}'))"])
    return code == 0, out


def validate_with_luaparser(file: Path) -> tuple[bool, str]:
    try:
        from luaparser import ast
    except Exception as exc:
        return False, f"luaparser unavailable: {exc}"

    try:
        ast.parse(file.read_text(encoding='utf-8'))
        return True, ''
    except Exception as exc:
        return False, str(exc)


def choose_validator() -> tuple[str, callable] | tuple[None, None]:
    if shutil.which('luac'):
        return 'luac -p', validate_with_luac
    if shutil.which('lua'):
        return 'lua loadfile', lambda f: validate_with_loadfile('lua', f)
    if shutil.which('luajit'):
        return 'luajit loadfile', lambda f: validate_with_loadfile('luajit', f)

    # luaparser is optional; detect by import attempt
    try:
        import luaparser  # noqa: F401

        return 'python luaparser', validate_with_luaparser
    except Exception:
        return None, None


def main() -> int:
    files = iter_lua_files(sys.argv[1:])
    if not files:
        print('No Lua files found to validate.')
        return 0

    validator_name, validator = choose_validator()
    if not validator:
        print('[WARN] No Lua validator available (missing luac/lua/luajit/luaparser). Skipping syntax check.')
        return 0

    print(f'[INFO] Using validator: {validator_name}')

    failed = False
    for file in files:
        if not file.exists():
            print(f'[FAIL] {file}: file not found')
            failed = True
            continue

        ok, details = validator(file)
        if ok:
            print(f'[OK]   {file}')
        else:
            print(f'[FAIL] {file}: {details}')
            failed = True

    return 1 if failed else 0


if __name__ == '__main__':
    raise SystemExit(main())
