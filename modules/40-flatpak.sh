#!/usr/bin/env bash
#
# 40-flatpak -- Flatpak, Flathub, and the apps you actually use.
#
# THE GOTCHA THIS MODULE EXISTS TO HANDLE:
#
# You cannot `flatpak install` at image build time. Flatpaks live in
# /var/lib/flatpak, and /var is runtime state -- it is NOT part of a bootc
# image. A `flatpak install` line in a Containerfile appears to succeed and
# then silently vanishes, because the directory it wrote to is not shipped.
#
# So the working pattern is: install the tooling and the app LIST into the
# image (which is /usr, and is shipped), then let a first-boot unit do the
# actual installing on the real machine where /var exists.
#
# The upside is real: apps live outside the base image entirely. Firefox
# updates on its own schedule without rebuilding or rebooting the OS, and the
# image stays small no matter how many apps you add.
#
set -euxo pipefail

dnf -y install flatpak

# The app list. Add a line, rebuild, and the next boot picks it up.
# Kept in /usr/share so it ships with the image and is visible to the unit.
install -d /usr/share/fedora-custom
cat > /usr/share/fedora-custom/flatpaks.list <<'EOF'
# One Flathub application ID per line. Comments and blanks ignored.
org.mozilla.firefox
EOF

install -d /usr/libexec
cat > /usr/libexec/fedora-custom-flatpak-setup <<'SCRIPT'
#!/usr/bin/env bash
# Adds Flathub and installs the listed apps. Runs once per machine, on the
# first boot that has a network.
set -euo pipefail

LIST=/usr/share/fedora-custom/flatpaks.list
STAMP=/var/lib/fedora-custom/flatpak-provisioned

flatpak remote-add --if-not-exists --system \
    flathub https://flathub.org/repo/flathub.flatpakrepo

while read -r app; do
    case "$app" in ''|\#*) continue ;; esac
    echo "installing flatpak: $app"
    # Non-fatal on purpose: one unavailable app must not stop the rest, and
    # must not leave the machine unprovisioned forever.
    flatpak install -y --system --noninteractive flathub "$app" || \
        echo "WARNING: could not install $app" >&2
done < "$LIST"

install -d "$(dirname "$STAMP")"
date -Is > "$STAMP"
SCRIPT
chmod +x /usr/libexec/fedora-custom-flatpak-setup

cat > /usr/lib/systemd/system/fedora-custom-flatpak.service <<'EOF'
[Unit]
Description=Install Flatpak applications on first boot
# Flathub is a network fetch, so wait for real connectivity rather than
# just for the interface to appear.
After=network-online.target
Wants=network-online.target
# The stamp file makes this genuinely once-per-machine. Delete the stamp to
# re-run it after editing the app list.
ConditionPathExists=!/var/lib/fedora-custom/flatpak-provisioned

[Service]
Type=oneshot
ExecStart=/usr/libexec/fedora-custom-flatpak-setup
RemainAfterExit=yes
# A flaky network on first boot should not permanently skip provisioning.
Restart=on-failure
RestartSec=30s

[Install]
WantedBy=multi-user.target
EOF

systemctl enable fedora-custom-flatpak.service
