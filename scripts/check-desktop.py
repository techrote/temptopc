#!/usr/bin/env python3
"""Check noVNC HTTP AND the actual VNC/RFB server behind it.

Serving vnc.html alone is not evidence that VNC port 5901 is accepting connections.
"""
from __future__ import annotations

import argparse
import socket
import sys
import time
import urllib.request


def probe() -> tuple[bool, str]:
    try:
        with socket.create_connection(("127.0.0.1", 5901), timeout=2) as sock:
            sock.settimeout(2)
            banner = bytearray()
            while len(banner) < 12:
                data = sock.recv(12 - len(banner))
                if not data:
                    break
                banner.extend(data)
            if not banner.startswith(b"RFB ") or len(banner) != 12:
                return False, f"VNC on 5901 returned invalid RFB banner: {bytes(banner)!r}"
    except (OSError, TimeoutError) as exc:
        return False, f"VNC backend 127.0.0.1:5901 unavailable: {exc}"
    try:
        with urllib.request.urlopen("http://127.0.0.1:6080/vnc.html", timeout=2) as response:
            if response.status != 200:
                return False, f"noVNC HTTP returned {response.status}"
            body = response.read(4096)
            if b"<!DOCTYPE" not in body and b"<html" not in body.lower():
                return False, "noVNC served unexpected content"
    except (OSError, TimeoutError) as exc:
        return False, f"noVNC HTTP 127.0.0.1:6080 unavailable: {exc}"
    return True, "PASS: noVNC HTTP 6080 and VNC/RFB 5901 are both responding"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--wait", type=int, default=0, help="maximum seconds to retry")
    args = parser.parse_args()
    deadline = time.monotonic() + max(0, args.wait)
    while True:
        ok, message = probe()
        if ok:
            print(message)
            return 0
        if time.monotonic() >= deadline:
            print("FAIL: " + message, file=sys.stderr)
            return 1
        time.sleep(0.5)


if __name__ == "__main__":
    raise SystemExit(main())
