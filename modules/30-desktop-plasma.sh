#!/usr/bin/env bash
#
# 30-desktop-plasma -- KDE Plasma, Wayland, and nothing else.
#
# This is NOT the `kde-desktop` group. That group pulls in the full Fedora KDE
# spin: an office suite, a mail client, games, educational software. Naming the
# packages individually is the difference between a 2 GB desktop and a 6 GB one.
#
# What you get: a session you can log into, a panel, a file manager, a terminal,
# settings, and working audio. Everything else is a Flatpak.
#
set -euxo pipefail

dnf -y install \
    plasma-desktop \
    plasma-workspace-wayland \
    sddm \
    sddm-kcm \
    dolphin \
    konsole \
    kscreen \
    plasma-nm \
    plasma-pa \
    kde-gtk-config \
    breeze-gtk \
    xdg-desktop-portal-kde

# Audio. PipeWire is the only sane choice now; wireplumber is its session
# manager and nothing routes without it.
dnf -y install \
    pipewire \
    pipewire-pulseaudio \
    pipewire-alsa \
    wireplumber

# Fonts. Skipping these is how you end up with a desktop full of tofu boxes.
dnf -y install \
    google-noto-sans-fonts \
    google-noto-serif-fonts \
    google-noto-emoji-fonts \
    liberation-fonts

systemctl enable sddm.service
systemctl set-default graphical.target
