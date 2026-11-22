# TempToPC setup

**Source available, live qualification pending.** This repository can configure a
Codespaces Linux desktop and project-associated Windows acceptance runner, but
creating the files does not automatically instantiate or test either machine.

## Linux Codespace: create, connect and recover

1. Visit https://github.com/techrote/temptopc, choose **Code → Codespaces →
   Create codespace on main**. Select at least 4 CPUs, 8 GiB RAM and 32 GiB
   storage. Codespaces charges and availability depend on your GitHub plan.
2. After the devcontainer has built, its post-start hook creates an XFCE
   desktop on DISPLAY=:9 using Xvfb, with a Falkon browser and terminal.
   The noVNC HTTP/WebSocket server listens on **127.0.0.1:6080** and
   x11vnc listens on **127.0.0.1:5901**. The latter is never forwarded.
3. In the Codespace's **Ports** tab, ensure port 6080 is **Private**,
   open its forwarded link and navigate to **/vnc.html**. Click Connect.
   Fetch the password in the Codespace editor's integrated terminal:

       bash scripts/desktop-status.sh --show-password

   This 8-character password is a legacy VNC secondary challenge. GitHub's
   private-port authentication is the primary barrier. **Never** mark port
   6080 as Public or organization-visible, or publish the VNC password.
4. The startup command verifies **both** the noVNC webpage and the VNC RFB
   handshake. If Connect does nothing, first check service status and logs:

       bash scripts/desktop-status.sh
       tail -n 30 ~/.cache/temptopc/vnc.log
       tail -n 30 ~/.cache/temptopc/xfce.log

   The first Codespace build used a post-start background process that could
   receive SIGHUP when the launcher exited. The current detached supervisor
   starts those processes in separate POSIX sessions. Fetch the repair with
   `git pull --ff-only` and run `bash scripts/start-desktop.sh` to apply it.
   You do **not** need to add port 6080 again if its forwarded URL already loads.
   If you copied or posted a VNC password, rotate it with
   `bash scripts/start-desktop.sh --rotate-password`, then retrieve the new
   password privately; never paste the replacement into a chat.
5. Inspect the graphical desktop. Use its **Launch Windows Acceptance**
   icon or the same terminal to manage project-associated workflows.
   To restart a failed desktop service, run:

       bash scripts/desktop-status.sh
       bash scripts/start-desktop.sh

   Local logs are under ~/.cache/temptopc and not committed. SSH is prepared
   with per-container host keys and public-key authentication for optional
   gh codespace ssh access.

### Wake, stop and retention

Wake-on-LAN cannot start a Codespace. Use https://github.com/codespaces
and click its name. From an **external, authenticated** GitHub CLI:

    gh codespace list
    gh codespace open --web
    gh codespace stop

The authenticated Codespaces REST API also supports
POST /user/codespaces/{codespace_name}/start with Codespaces lifecycle
permission. Never include the token in an unauthenticated public launcher.

GitHub's default inactivity stop is generally 30 minutes, even if a VNC
client is open; noVNC input may not reset GitHub's editor activity timer.
A Codespace stops after a maximum 12-hour lifetime. Stopped compute is
not charged, but storage may be. Inactive Codespaces are auto-deleted
after 30 days by default, adjustable within GitHub's limit.
Save and commit work before long inactivity or rebuilds.

## Configure Windows acceptance in each target project

GitHub's additional product terms require GitHub-hosted Actions and
Codespaces to support development/testing of their associated repository,
not arbitrary unrelated cloud computing. Accordingly, the Windows workflow
is published as a **reusable workflow** in TempToPC and should be invoked
from **the project repository actually under test**.

Generate an immutable-SHA-pinned caller workflow in the Codespace:

    bash scripts/generate-caller.sh ./build/temptopc-acceptance.yml

Review the generated YAML. Have the project's developer commit it as
.github/workflows/temptopc-acceptance.yml on THAT project's default branch.
The generator uses the latest TempToPC main commit SHA so future edits to
TempToPC cannot silently alter an existing project's acceptance workflow.

Configure Actions repository secrets in the **calling project**:

- **TAILSCALE_AUTHKEY**: create a Tailscale key with an ephemeral,
  reusable and restricted tag; preapprove it if device approval is enabled.
  Configure Tailscale ACLs to permit only your authorized device/user
  to connect to TCP/3389 on tagged acceptance runners. Never use a broad
  rule permitting all tailnet members. Tailscale recommends federated
  OIDC over long-lived secrets; the authkey is a straightforward bootstrap.
- **TEMPTOPC_RDP_PASSWORD**: choose a unique, strong password of at least
  20 characters, known to you. The temporary account username is
  **temptopc-test**. It is not an administrator.

Install and sign into Tailscale on your own Windows machine. No RDP port
is forwarded onto the public Internet; the runner permits only tailnet
IPv4 address connections plus the required tailnet ACL policy.

## Spawn Windows from the Linux desktop

The GUI shortcut opens repository/duration dialogs and then displays the authenticated dispatcher result in a terminal. The same commands work in
any authenticated shell on the Linux Codespace:

    bash scripts/windows.sh start techrote/PlasmaTerm 60
    bash scripts/windows.sh list techrote/PlasmaTerm
    bash scripts/windows.sh view techrote/PlasmaTerm 12345678
    bash scripts/windows.sh cancel techrote/PlasmaTerm 12345678

The project must already contain its caller workflow on its default branch.
This dispatches a **new ephemeral Windows hosted runner** by the project's
GitHub Actions API. It does not wake an existing Windows VM by packet.

The Codespace's automatic GITHUB_TOKEN may be scoped to TempToPC and
unable to dispatch Actions in other repositories. If so, authenticate
a personal GitHub CLI session in the Codespace using the GitHub device flow:

    env -u GITHUB_TOKEN -u GH_TOKEN gh auth login -h github.com --web -s repo,workflow
    env -u GITHUB_TOKEN -u GH_TOKEN bash scripts/windows.sh start techrote/PlasmaTerm 60

The graphical launcher and scripts/windows.sh automatically prefer that
separately configured GitHub CLI identity when ~/.config/gh/hosts.yml exists;
otherwise they use the Codespace-provided token. A failed dispatch is never
silently retried, to avoid accidentally spawning duplicate Windows jobs.

This uses the manually authorized account instead of the automatically injected,
possibly narrow Codespaces token. Do not paste tokens into terminal history,
chat, scripts, URLs or pull-request comments. Store the resulting credentials
only in a trusted Codespace you control; they can be read by processes running
as your Codespace user.

A direct TempToPC Windows dispatch
(**bash scripts/windows.sh start techrote/temptopc 30**) is only for
qualifying the TempToPC infrastructure itself.

In the Windows Actions job summary, read the **private 100.x.y.z
Tailscale address**. On your Windows PC, launch **mstsc**, connect to
that IP, then sign in as **temptopc-test** with the calling project's
TEMPTOPC_RDP_PASSWORD. The machine is Windows Server 2022 with virtual
graphics, not your physical Windows 11/NVIDIA/Vulkan environment.

### Test a source-specific build

The per-project caller optionally accepts all three fields together:
**candidate_run_id**, **candidate_artifact**, and **candidate_sha**.
The reusable workflow checks that the producer run is completed,
successful, belongs to the **calling repository** (not a fork), and
reports the specified full 40-character SHA. It downloads the named
artifact but **does not auto-run it**. The human chooses what to
inspect, install or execute. Matching SHA and CI success do not
constitute a malware audit.

The source checkout and staged artifact path are described by
C:\TempToPC\START-HERE.txt. Use C:\TempToPC\Feedback to save screenshots
or PASS/FAIL observations. Only that feedback folder is uploaded as a
7-day Actions artifact. A cancelled run may skip artifact cleanup:
copy important evidence off the machine before cancelling.

Windows sessions last 30, 60, 120, 240 or 300 minutes, with an outer
350-minute job timeout. The caller has no schedule or automatic start,
and serializes acceptance sessions in each target repo. This is not
a subscription or persistent cloud desktop service.

## Security, qualification and boundaries

**Live tests still required:** build a fresh Codespace, confirm private
6080 forwarding and noVNC/keyboard/mouse, restart and stop; check
unauthenticated VNC failure; verify GitHub CLI manual dispatch refusal
without Actions permissions; create one authorized TempToPC self-test
Windows runner, inspect Tailscale-only RDP and the non-admin account;
prove connection, desktop launch, disconnect/reconnect, cancellation,
timed shutdown and feedback capture. Check actual machine/source
identities before claiming any acceptance result.

A Codespace does not expose KVM/Hyper-V to run Windows efficiently. A
Windows Actions runner is Windows Server with virtual graphics, and
an RDP session may differ from the service session in which Actions
build/test commands execute. It cannot establish NVIDIA/Vulkan frame
pacing, hardware GPU publication timing, physical display feel,
Windows 11 driver issues or full production performance.

Official references:
- https://docs.github.com/en/codespaces/about-codespaces/understanding-the-codespace-lifecycle
- https://docs.github.com/en/codespaces/developing-in-a-codespace/forwarding-ports-in-your-codespace
- https://docs.github.com/en/rest/codespaces/codespaces
- https://docs.github.com/en/site-policy/github-terms/github-terms-for-additional-products-and-features
- https://tailscale.com/docs/integrations/github/github-action

## First Windows acceptance: practical operator checklist

Before using the Linux graphical launcher, create one Tailscale tailnet
(or use an existing one) and install its Windows client on the PC from
which you will run mstsc. Current Tailscale GitHub Action v4 accepts
a tagged, reusable, ephemeral auth key; avoid a non-expiring unrestricted
key. In the Tailscale admin console:

1. In Access controls, declare an owned tag such as `tag:temptopc-accept`,
   and allow only the user's specific Tailscale identity/devices to reach
   `tag:temptopc-accept:3389`. Keep this role minimal; do not permit
   the ephemeral runner to reach arbitrary other tailnet devices.
2. Under Settings → Keys, choose **Generate auth key**. Select **Reusable**,
   **Ephemeral**, and `tag:temptopc-accept`, then **Generate key**.
   If device approval is enabled, choose **Pre-approved**. Copy the
   secret directly to GitHub's secret editor, never into chat or a PR.
3. At `https://github.com/techrote/temptopc/settings/secrets/actions`,
   click **New repository secret** and set:
   `TAILSCALE_AUTHKEY` = the generated key, and
   `TEMPTOPC_RDP_PASSWORD` = a distinct strong 20+ character password.
   The Windows login name will be `temptopc-test`. Do not share the values.
4. In the Codespace terminal, run `git pull --ff-only`, then
   `bash scripts/test-windows-launcher.sh` to exercise mock CLI/GUI dispatch
   with **no paid Windows runner**. Next run
   `bash scripts/windows.sh preflight techrote/temptopc`.
   Preflight checks the active workflow and, when allowed by GitHub's API,
   the **presence of secret names** (never their values).
5. Double-click **Launch Windows Acceptance** on XFCE, leave the default
   repository `techrote/temptopc`, select **30 minutes**, read preflight,
   and explicitly click **Launch Windows**. It dispatches one
   TempToPC **infrastructure self-test**. A successful dispatch is not
   an RDP success; consult that run's Actions job summary.
6. On your own Windows PC, sign in to the same Tailscale network.
   Run `mstsc`, enter the runner's private `100.x.y.z` address
   from the Actions job summary, and sign in as `temptopc-test`
   with the secret you configured. Check that the desktop displays
   **TempToPC acceptance info.txt**, and verify `C:\TempToPC\Feedback`
   is writable. Disconnect/reconnect once before ending the run.

The Windows workflow now checks that Tailscale is connected and
TCP/3389 is actually listening before reporting its private IP.
If no Windows run is created, check launcher preflight/gh credentials;
if a run is created but fails, inspect the failing Actions step.
The Codespace's injected token may be too restricted for workflow
dispatch; use `gh auth login --web` to authorize a user-level GitHub CLI
identity in that trusted Codespace.

### Functional test versus live acceptance

`scripts/test-windows-launcher.sh` replaces `gh`, `zenity` and
`xfce4-terminal` with local mocks. Passing it proves command validation,
preflight, refusal paths, cancellation and the intended dispatch arguments.
It **cannot** prove a real GitHub Actions run, Tailscale authentication,
remote RDP logon, Windows GUI interaction, or GPU equivalence.
Record those separately after the first live self-test.
