#!/usr/bin/env python3
"""Launch one Codespaces desktop daemon in an independent POSIX session."""
from __future__ import annotations

import os
from pathlib import Path
import subprocess
import sys
import tempfile


def main() -> int:
    if len(sys.argv) < 5 or sys.argv[3] != "--":
        print("usage: spawn-detached.py PIDFILE LOGFILE -- COMMAND [ARGS...]", file=sys.stderr)
        return 2
    pidfile = Path(sys.argv[1])
    logfile = Path(sys.argv[2])
    command = sys.argv[4:]
    if not command:
        return 2
    pidfile.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    logfile.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    with logfile.open("ab", buffering=0) as log:
        child = subprocess.Popen(
            command,
            stdin=subprocess.DEVNULL,
            stdout=log,
            stderr=subprocess.STDOUT,
            close_fds=True,
            start_new_session=True,
        )
    fd, tmp = tempfile.mkstemp(prefix=f".{pidfile.name}.", dir=pidfile.parent)
    try:
        os.fchmod(fd, 0o600)
        with os.fdopen(fd, "w", encoding="ascii") as out:
            out.write(f"{child.pid}\n")
        os.replace(tmp, pidfile)
    finally:
        if os.path.exists(tmp):
            os.unlink(tmp)
    print(f"started PID {child.pid}: {command[0]}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
