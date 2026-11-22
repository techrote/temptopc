Reusable remote graphical development and acceptance tooling.

| Component | Purpose | Access |
|---|---|---|
| Linux Codespace | XFCE, noVNC, Falkon, terminal, GitHub CLI | Private forwarded port **6080** |
| Windows acceptance | Temporary Windows Server RDP test session | Tailscale private IP + Windows Remote Desktop |
| Controller | Dispatch/cancel Windows acceptance from Linux | Desktop **Launch Windows Acceptance** or terminal |

The Windows component is a **reusable workflow invoked by the repository under test**. It is not a Windows VM inside Linux, a publicly exposed VNC endpoint or an unrestricted hosted computer. GitHub requires both Codespaces and hosted Actions usage to relate to the development/testing of the associated project.

## First run

1. At https://github.com/techrote/temptopc choose **Code → Codespaces → Create codespace on main**. The container installs and starts the Linux GUI.
2. In the Codespace **Ports** panel, open port **6080**, whose visibility must be **Private**. Navigate to **/vnc.html**.
3. In a Codespace terminal, run **bash scripts/desktop-status.sh --show-password** and enter the one-time VNC password.
4. To launch Windows for a project, install the small caller workflow in that project's repository, configure its Tailscale and RDP secrets, then dispatch through **scripts/windows.sh start OWNER/REPO 60**.

See **[Full setup, security and operating guide](docs/SETUP.md)**.

## Lifecycle

A stopped Codespace is started through https://github.com/codespaces or an externally authenticated **gh codespace open --web** command, not Wake-on-LAN. The running Linux Codespace can dispatch a temporary Windows Actions job in the target repository; a stopped Codespace cannot dispatch anything itself.

Source files have been published but **a real Codespace GUI/RDP session has not been operated or qualified from this chat**. Committing code does not instantiate or wake a machine.
