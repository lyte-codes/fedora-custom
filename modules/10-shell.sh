#!/usr/bin/env bash
#
# 10-shell -- the things that make a terminal bearable.
#
# Separate from 00-core because a headless appliance does not need any of it,
# and on a machine you actually sit at, all of it.
#
set -euxo pipefail

dnf -y install \
    bash-completion \
    git \
    vim-enhanced \
    tmux \
    curl \
    wget \
    rsync \
    htop \
    ripgrep \
    fd-find \
    jq \
    tree \
    unzip \
    tar

# nodocs is set globally in dnf.conf, which also strips man pages. If you want
# them back for this class of tool specifically, drop `tsflags=nodocs` from
# overlay/etc/dnf/dnf.conf rather than special-casing it here -- a global
# setting quietly overridden in one module is how a build becomes unpredictable.
