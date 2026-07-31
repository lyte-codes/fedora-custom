#!/usr/bin/env bash
#
# AMD graphics. The easy case.
#
# The kernel driver (amdgpu) is in-tree and the firmware is in linux-firmware,
# so there is no module to compile and nothing to sign for Secure Boot. All
# this adds is the userspace half: OpenGL, Vulkan and video acceleration.
#
set -euxo pipefail

dnf -y install \
    mesa-dri-drivers \
    mesa-vulkan-drivers \
    vulkan-loader \
    libva \
    libva-utils \
    mesa-va-drivers

# linux-firmware is already in the bootc base, which is where the amdgpu
# firmware blobs come from. Installing it again would be a no-op.
