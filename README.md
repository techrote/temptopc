# TempToPC

A reusable, on-demand development and graphical acceptance-workstation toolkit.

- **Linux**: a GitHub Codespaces dev container with a private browser-accessible XFCE/noVNC desktop for development and testing this toolkit.
- **Windows**: a reusable, manually invoked GitHub Actions workflow for private RDP acceptance sessions, called from the repository whose software is being tested.
- **Orchestration**: dispatch eligible project acceptance runs from the Linux Codespace using an authenticated GitHub CLI.

> This repository does not create a Windows VM inside Codespaces. A stopped Codespace is started through GitHub, not by Wake-on-LAN. All hosted usage must comply with GitHub’s project-related development and testing terms.

See [the setup guide](docs/SETUP.md) for creation, secrets, security, and lifecycle. No live Codespace or Windows runner is provisioned merely by committing these files.
