#!/usr/bin/env bash
#
# Intel graphics. Also the easy case.
#
# i915 (and xe on Arc / Meteor Lake and newer) are in-tree. This adds the
# userspace stack only.
#
set -euxo pipefail

dnf -y install \
    mesa-dri-drivers \
    mesa-vulkan-drivers \
    vulkan-loader \
    libva \
    libva-utils \
    intel-media-driver

# intel-media-driver covers Broadwell and newer. For pre-2015 hardware the
# older libva-intel-driver is the one that works instead -- swap it in here
# rather than installing both, since they conflict over the same VA-API entry.
