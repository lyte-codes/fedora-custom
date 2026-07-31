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
# So: the tooling and the app LIST go into /usr (which is shipped), and a
# first-boot unit does the installing on the real machine where /var exists.
# A second unit keeps them updated, because nothing else on this image would.
#
set -euxo pipefail

dnf -y install flatpak

# The app list. Add a line, rebuild, and the next boot picks it up.
install -d /usr/share/fedora-custom
cat > /usr/share/fedora-custom/flatpaks.list <<'EOF'
# One Flathub application ID per line. Comments and blanks ignored.
org.mozilla.firefox
EOF

install -d /usr/libexec
cat > /usr/libexec/fedora-custom-flatpak-setup <<'SCRIPT'
#!/usr/bin/env bash
# Adds Flathub and installs the listed apps. Runs on each boot until it
# fully succeeds, then never again.
set -euo pipefail

LIST=/usr/share/fedora-custom/flatpaks.list
STAMP=/var/lib/fedora-custom/flatpak-provisioned

# A missing list is nothing to do, not an error -- otherwise the unit would
# restart-loop every 30s with a terse redirect failure and no useful message.
[ -r "$LIST" ] || { echo "no flatpak list at $LIST, nothing to do"; exit 0; }

flatpak remote-add --if-not-exists --system \
    flathub https://flathub.org/repo/flathub.flatpakrepo

# Why the stamp is NOT written unconditionally:
#
# The obvious version of this loop makes each install non-fatal with `|| echo`,
# which means the script exits 0 even when every single install failed. The
# stamp gets written, ConditionPathExists then skips the unit forever, and
# Restart=on-failure never fires because nothing ever failed. One bad first
# boot -- a captive portal, a CDN blip, a suspend mid-download -- leaves the
# machine permanently without a browser, reporting "active (exited)".
#
# So: keep each install non-fatal so one dead app ID cannot block the others,
# but track it, and only claim provisioned when everything actually landed.
failed=0

# Read the list on fd 3, not stdin. On stdin, any child that reads a byte
# (flatpak, ostree, curl) silently eats list entries and the remaining apps
# are never attempted -- invisible with one app, baffling with ten.
while read -r app <&3; do
    case "$app" in ''|\#*) continue ;; esac
    echo "installing flatpak: $app"
    # --or-update matters: plain `install` on an existing ref prints "already
    # installed, skipping" and does NOT update it.
    if ! flatpak install -y --system --noninteractive --or-update flathub "$app" </dev/null; then
        echo "WARNING: could not install $app" >&2
        failed=1
    fi
done 3< "$LIST"

if [ "$failed" -ne 0 ]; then
    echo "one or more flatpaks failed; not marking provisioned so this retries" >&2
    exit 1
fi

install -d "$(dirname "$STAMP")"
date -Is > "$STAMP"
echo "flatpak provisioning complete"
SCRIPT
chmod +x /usr/libexec/fedora-custom-flatpak-setup

cat > /usr/lib/systemd/system/fedora-custom-flatpak.service <<'EOF'
[Unit]
Description=Install Flatpak applications on first boot
# Flathub is a network fetch, so wait for real connectivity rather than just
# for an interface to appear. NetworkManager.service carries
# Also=NetworkManager-wait-online.service, so enabling NM in 00-core.sh is
# enough -- this Wants= is what actually pulls the target in.
After=network-online.target
Wants=network-online.target
# Genuinely once per machine. Delete the stamp to re-run after editing the list.
ConditionPathExists=!/var/lib/fedora-custom/flatpak-provisioned
ConditionPathExists=/usr/share/fedora-custom/flatpaks.list
# Retry indefinitely rather than giving up after the default 5 attempts: a
# machine that boots on a flaky network should still end up with a browser.
StartLimitIntervalSec=0

[Service]
Type=oneshot
ExecStart=/usr/libexec/fedora-custom-flatpak-setup
RemainAfterExit=yes
# systemd DISABLES the start timeout for Type=oneshot by default. That is the
# right instinct for a several-hundred-MB runtime download, but it means a
# half-open connection (laptop leaves wifi range mid-pull) hangs in
# `activating` forever and Restart= can never fire, because the service never
# exits. A generous ceiling keeps the slow-but-working case alive while still
# letting the wedged case fail and retry.
TimeoutStartSec=30min
Restart=on-failure
RestartSec=30s

[Install]
WantedBy=multi-user.target
EOF

# Nothing on this image would ever update a Flatpak otherwise. Flatpak ships no
# auto-update mechanism of its own -- desktops normally delegate it to a
# software centre, and this image deliberately has none. Without this timer
# Firefox stays frozen at whatever version first boot happened to fetch, which
# for a browser is a security problem, not a papercut.
cat > /usr/lib/systemd/system/fedora-custom-flatpak-update.service <<'EOF'
[Unit]
Description=Update installed Flatpak applications
After=network-online.target
Wants=network-online.target
ConditionPathExists=/var/lib/fedora-custom/flatpak-provisioned

[Service]
Type=oneshot
ExecStart=/usr/bin/flatpak update -y --system --noninteractive
TimeoutStartSec=30min
EOF

cat > /usr/lib/systemd/system/fedora-custom-flatpak-update.timer <<'EOF'
[Unit]
Description=Daily Flatpak application updates

[Timer]
OnCalendar=daily
# Machines that are off overnight must still update, rather than silently
# skipping every missed window.
Persistent=true
# Do not have every machine hit Flathub at midnight exactly.
RandomizedDelaySec=1h

[Install]
WantedBy=timers.target
EOF

systemctl enable fedora-custom-flatpak.service
systemctl enable fedora-custom-flatpak-update.timer
