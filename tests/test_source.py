"""Cheap, non-privileged source checks. They do not qualify a live Codespace."""
import json
from pathlib import Path
import re
import subprocess
import unittest
import yaml

ROOT = Path(__file__).resolve().parents[1]


def workflow(path):
    result = yaml.load((ROOT / path).read_text(encoding="utf-8"), Loader=yaml.BaseLoader)
    if not isinstance(result, dict):
        raise AssertionError(f"Not a YAML map: {path}")
    return result


class TempToPCSourceContract(unittest.TestCase):
    def test_devcontainer_private_port(self):
        config = json.loads((ROOT / ".devcontainer/devcontainer.json").read_text())
        self.assertEqual(config["remoteUser"], "vscode")
        self.assertEqual(config["forwardPorts"], [6080])
        self.assertEqual(config["portsAttributes"]["6080"]["visibility"], "private")
        self.assertIn("scripts/start-desktop.sh", config["postStartCommand"])
        self.assertNotIn("privileged", str(config).lower())

    def test_shell_syntax(self):
        for sh in sorted((ROOT / "scripts").glob("*.sh")):
            with self.subTest(sh=sh.name):
                proc = subprocess.run(["bash", "-n", str(sh)], capture_output=True, text=True)
                self.assertEqual(proc.returncode, 0, proc.stderr)

    def test_novnc_only_loopback(self):
        script = (ROOT / "scripts/start-desktop.sh").read_text()
        self.assertIn("127.0.0.1:6080", script)
        self.assertIn("-localhost -rfbport 5901", script)
        self.assertNotIn("0.0.0.0:6080", script)
        self.assertIn("ssh-keygen -A", script)
        self.assertIn("vnc-password", script)

    def test_reusable_manual_windows(self):
        file = workflow(".github/workflows/windows-desktop.yml")
        self.assertEqual(set(file["on"]), {"workflow_call"})
        self.assertEqual(file["permissions"], {"contents": "read", "actions": "read"})
        job = file["jobs"]["windows-acceptance"]
        self.assertEqual(job["runs-on"], "windows-2022")
        self.assertIn("workflow_dispatch", job["if"])
        body = (ROOT / ".github/workflows/windows-desktop.yml").read_text()
        self.assertIn("tailscale/github-action@v4", body)
        self.assertIn("100.64.0.0/10", body)
        self.assertNotIn("disable-netfirewall", body.lower())
        self.assertIn("if: always()", body)
        self.assertIn("gh api", body)
        self.assertIn("head_sha", body)
        self.assertNotIn("0.0.0.0:3389", body)
        self.assertFalse(re.search(r"\[\[\s*(?:github|inputs|secrets)\.", body))

    def test_manual_selftest_and_pinned_project_caller(self):
        selftest = workflow(".github/workflows/windows-desktop-selftest.yml")
        self.assertEqual(set(selftest["on"]), {"workflow_dispatch"})
        self.assertIn("github.actor == 'techrote'", selftest["jobs"]["verify-tempotopc"]["if"])
        template = (ROOT / "templates/caller.yml").read_text()
        self.assertIn("@%TEMPTOPC_COMMIT%", template)
        self.assertIn("workflow_dispatch", template)
        self.assertIn("candidate_artifact:", template)
        self.assertIn("secrets.TEMPTOPC_RDP_PASSWORD", template)

    def test_dispatch_is_manually_gated(self):
        bash = (ROOT / "scripts/windows.sh").read_text()
        self.assertIn("gh workflow run", bash)
        self.assertIn("gh run cancel", bash)
        self.assertNotIn("--ref main", bash)
        self.assertIn("windows-desktop-selftest.yml", bash)


if __name__ == "__main__":
    unittest.main()
