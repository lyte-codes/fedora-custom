# A custom Fedora, built as a container, bootable as an operating system.
#
# The base is fedora-bootc, not Silverblue or Workstation: it ships no desktop,
# no office suite and no media stack, so you are adding to a minimal system
# rather than deleting from a full one. That is the difference between a lean
# image and a big image with holes in it.
#
# 44 is the current stable Fedora. 45 exists but is rawhide -- pin deliberately
# rather than tracking latest, or an upstream change lands on your PC unannounced.
ARG FEDORA_VERSION=44
FROM quay.io/fedora/fedora-bootc:${FEDORA_VERSION}

# --- Modularity ---------------------------------------------------------------
#
# Each concern is one script in modules/; a profile in profiles/ names the set
# to run. A variant is therefore a different build argument, not a different
# Containerfile:
#
#   --build-arg PROFILE=desktop         Xfce + Firefox            (the default)
#   --build-arg PROFILE=desktop-plasma  the same, with KDE Plasma
#   --build-arg PROFILE=minimal         headless: boots, networks, takes ssh
#   --build-arg PROFILE=normal          headless + a usable terminal
#   --build-arg PROFILE=max             headless + compilers and containers
#
# Turning an app off is deleting a line from a profile. Adding a capability is
# adding a file to modules/. Neither should mean editing this file.
#
# This default matches CI's, so a bare `podman build .` locally and a push to
# main produce the same image. They disagreed once; it was confusing.
ARG PROFILE="desktop"

# Escape hatch: set MODULES to bypass the profile entirely for a one-off build.
# Empty means "use the profile", which is what you want almost always.
ARG MODULES=""

# --- Hardware -----------------------------------------------------------------
#
# Kept separate from MODULES because it changes for a different reason: modules
# are what the machine DOES, drivers are what the machine IS. Swap the GPU and
# only this argument changes.
#
#   --build-arg DRIVERS="amd"      (or intel, or nvidia -- see drivers/README.md)
#
# Empty is a valid, working answer: the image boots fine to a console with no
# GPU driver, so you are not blocked on choosing hardware.
ARG DRIVERS=""

# The overlay is copied in BEFORE anything runs, so /etc/dnf/dnf.conf is already
# in place and every dnf call below inherits the no-weak-deps default.
COPY overlay/ /
COPY modules/ /tmp/modules/
COPY drivers/ /tmp/drivers/
COPY profiles/ /tmp/profiles/

RUN set -eux; \
    # Resolve the profile into a module list, unless MODULES overrides it.
    # Comments and blank lines in a profile are stripped, so profiles can
    # explain themselves.
    if [ -n "${MODULES}" ]; then \
        RESOLVED="${MODULES}"; \
        echo "==> modules from MODULES override: ${RESOLVED}"; \
    else \
        [ -f "/tmp/profiles/${PROFILE}" ] || { \
            echo "no such profile: ${PROFILE}" >&2; \
            echo "available: $(ls /tmp/profiles | tr '\n' ' ')" >&2; exit 1; }; \
        RESOLVED="$(grep -vE '^[[:space:]]*#|^[[:space:]]*$' "/tmp/profiles/${PROFILE}" | tr '\n' ' ')"; \
        echo "==> profile ${PROFILE}: ${RESOLVED}"; \
    fi; \
    for m in ${RESOLVED}; do \
        script="/tmp/modules/${m}.sh"; \
        [ -f "$script" ] || { echo "no such module: ${m}" >&2; exit 1; }; \
        echo "==> module ${m}"; \
        bash "$script"; \
    done; \
    # Drivers run after modules so they can rely on the base being present.
    for d in ${DRIVERS}; do \
        script="/tmp/drivers/${d}.sh"; \
        [ -f "$script" ] || { echo "no such driver: ${d}" >&2; exit 1; }; \
        echo "==> driver ${d}"; \
        bash "$script"; \
    done; \
    # Any blobs dropped into drivers/firmware/ land alongside linux-firmware.
    # Nearly always empty -- linux-firmware already covers the common cases.
    if [ -d /tmp/drivers/firmware ] && [ -n "$(ls -A /tmp/drivers/firmware 2>/dev/null | grep -v '^\.gitkeep$')" ]; then \
        echo "==> installing custom firmware blobs"; \
        install -d /usr/lib/firmware; \
        cp -rv /tmp/drivers/firmware/. /usr/lib/firmware/; \
        rm -f /usr/lib/firmware/.gitkeep; \
    fi; \
    rm -rf /tmp/modules /tmp/drivers /tmp/profiles; \
    # Everything below is size, not function. A bootc image ships whatever is
    # left in the filesystem, so caches left behind are permanent weight on
    # every machine that boots this.
    dnf -y clean all; \
    rm -rf /var/cache/dnf/* /var/log/dnf* /tmp/* /var/tmp/*; \
    # Catches the mistakes that only show up at boot -- wrong /var layout,
    # missing kernel, unlabelled files. Cheap here, expensive on the PC.
    bootc container lint

# bootc needs to know these are images it can upgrade between.
LABEL containers.bootc="1"
