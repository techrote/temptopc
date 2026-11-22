# Dedicated development container; no nested Windows VM, privileged Docker or KVM.
FROM mcr.microsoft.com/devcontainers/base:noble@sha256:d7c468679f45a52ad3673d06656b5bf16e488990b17216a1fa295d9e1f89d724

USER root
RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      dbus-x11 xfce4 xfce4-terminal x11vnc xvfb x11-utils xauth \
      novnc websockify tigervnc-tools fonts-dejavu-core falkon \
      zenity gh git git-lfs jq openssl curl ca-certificates python3 \
      openssh-server \
    && install -d -m 0755 /etc/ssh/sshd_config.d \
    && printf '%s\n' \
       'PubkeyAuthentication yes' \
       'PasswordAuthentication no' \
       'KbdInteractiveAuthentication no' \
       'PermitRootLogin no' \
       'AllowTcpForwarding yes' \
       > /etc/ssh/sshd_config.d/90-temptopc.conf \
    && chmod 0644 /etc/ssh/sshd_config.d/90-temptopc.conf \
    && rm -f /etc/ssh/ssh_host_*_key /etc/ssh/ssh_host_*_key.pub \
    && rm -rf /var/lib/apt/lists/*
USER vscode
