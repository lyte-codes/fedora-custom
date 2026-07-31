#!/usr/bin/env bash
#
# 30-desktop-xfce -- Xfce, the lighter alternative to Plasma.
#
# Same restraint as the Plasma module: individual packages, not the
# `xfce-desktop-environment` group, which drags in a browser, a mail client
# and a media player you are going to replace with Flatpaks anyway.
#
# Trade-off versus Plasma: Xfce is smaller and lighter, but still X11-first --
# its Wayland support is experimental. On a PC being built now that is worth
# thinking about, since X11 is winding down.
#
set -euxo pipefail

dnf -y install \
    xfce4-session \
    xfce4-panel \
    xfwm4 \
    xfdesktop \
    xfce4-settings \
    xfce4-terminal \
    thunar \
    thunar-volman \
    xfce4-pulseaudio-plugin \
    network-manager-applet \
    lightdm \
    lightdm-gtk-greeter \
    xdg-desktop-portal-gtk

dnf -y install \
    pipewire \
    pipewire-pulseaudio \
    pipewire-alsa \
    wireplumber

dnf -y install \
    google-noto-sans-fonts \
    google-noto-serif-fonts \
    google-noto-emoji-fonts \
    liberation-fonts

systemctl enable lightdm.service
systemctl set-default graphical.target
