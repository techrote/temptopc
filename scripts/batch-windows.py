#!/usr/bin/env python3
"""Manual, single-project TempToPC batch dispatcher; requires explicit operator approval."""
import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CATALOG = json.loads((ROOT / "docs/gui-batch-2026-11-23.json").read_text(encoding="utf-8"))
GROUPS = {g["repo"].split("/")[-1]: g for g in CATALOG["groups"]}

def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else "list"
    if cmd == "list":
        for g in CATALOG["groups"]:
            print(f'{g["repo"]:34} {len(g["prs"]):2} PRs  {g["minutes"]:3} min   {g["limitations"]}')
        print("No sessions started.")
        return
    if cmd not in ("preflight", "launch") or len(sys.argv) != 3 or sys.argv[2] not in GROUPS:
        raise SystemExit("Usage: python3 scripts/batch-windows.py list|preflight|launch <project-short-name>")
    group = GROUPS[sys.argv[2]]
    repo = group["repo"]
    command = ["bash", str(ROOT / "scripts/windows.sh")]
    subprocess.run(command + ["preflight", repo], check=True)
    if cmd == "preflight":
        print("Preflight only; no Windows runner started.")
        return
    print(f'One {group["minutes"]}-minute Windows RDP runner for {repo}, from existing project source pins.')
    if input("Type LAUNCH to dispatch (anything else cancels): ").strip() != "LAUNCH":
        raise SystemExit("Cancelled")
    invocation = command + ["start", repo, str(group["minutes"])]
    a = group.get("artifact")
    if a:
        invocation += [str(a["run_id"]), a["name"], a["sha"]]
    subprocess.run(invocation, check=True)

if __name__ == "__main__":
    main()
