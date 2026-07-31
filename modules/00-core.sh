#!/usr/bin/env bash
#
# 00-core -- the floor. Everything else assumes this ran.
#
# Deliberately small. The temptation with a base module is to put "things I
# always want" in it, and then every variant carries them whether it needs them
# or not. If something is only wanted on a desktop, it belongs in a desktop
# module, not here.
#
set -euxo pipefail

dnf -y install \
    systemd-resolved \
    NetworkManager \
    openssh-server \
    sudo \
    less \
    which

# Predictable DNS and networking on a machine with no desktop to manage them.
systemctl enable systemd-resolved.service
systemctl enable NetworkManager.service
systemctl enable sshd.service

# Journals default to growing until the disk notices. Cap them: on an immutable
# system /var is the only writable state that matters, and logs are the thing
# most likely to fill it.
mkdir -p /etc/systemd/journald.conf.d
cat > /etc/systemd/journald.conf.d/00-size.conf <<'EOF'
[Journal]
SystemMaxUse=200M
SystemMaxFileSize=50M
EOF
