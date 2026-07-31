#!/usr/bin/env bash
#
# NVIDIA proprietary driver.
#
# ############################################################################
# # THIS IS A SCAFFOLD, NOT A WORKING SCRIPT. Read drivers/README.md first.  #
# ############################################################################
#
# Why it cannot just be a dnf install like amd.sh and intel.sh:
#
#   The proprietary driver is an OUT-OF-TREE kernel module. It has to be
#   compiled against the exact kernel inside this image. That means the build
#   needs the matching kernel-devel package, and it means every Fedora kernel
#   bump recompiles it -- so a routine `bootc upgrade` can leave you at a
#   console with no display driver.
#
#   Under Secure Boot it is worse: the module must be signed with a key you
#   generate and enrol in the machine's firmware by hand, at the console, once.
#
# The approach that works, in outline:
#
#   1. Enable RPM Fusion nonfree (the driver is not in Fedora proper).
#   2. Install kernel-devel matching the image's kernel EXACTLY -- read the
#      version out of /usr/lib/modules/, do not assume it matches the host or
#      the newest available.
#   3. Install akmod-nvidia and force the module to build at image build time,
#      not first boot. On an immutable system there is no writable /usr at
#      boot, so a module that builds lazily never builds at all.
#   4. Verify the .ko actually exists before the image is considered good.
#
# Sketch -- expect to iterate on this:
#
#   KVER=$(basename /usr/lib/modules/*)
#   dnf -y install \
#       "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm" \
#       "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm"
#   dnf -y install "kernel-devel-${KVER}" akmod-nvidia xorg-x11-drv-nvidia-cuda
#   akmods --force --kernels "${KVER}"
#   modinfo -k "${KVER}" nvidia >/dev/null || { echo "nvidia module did not build"; exit 1; }
#
# That last line matters more than the rest. Without it the image builds
# "successfully" with no driver in it, and you find out when the PC boots to a
# black screen.
#
# Before committing to this: nouveau (in-tree, already present, no work) is
# fine for a desktop that is not gaming or doing CUDA. And AMD avoids the whole
# problem permanently.

set -euo pipefail

echo "drivers/nvidia.sh is a scaffold and has not been implemented." >&2
echo "Read drivers/README.md, then fill this in deliberately." >&2
exit 1
