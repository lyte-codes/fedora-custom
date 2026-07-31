#!/usr/bin/env bash
#
# 20-dev -- development tooling.
#
# An example of a module you would leave OUT of a server build. Delete it,
# rename it, or copy it as the template for your own -- the module list in the
# Containerfile is the only place that references it.
#
set -euxo pipefail

dnf -y install \
    podman \
    buildah \
    skopeo \
    make \
    gcc \
    python3 \
    python3-pip

# Rootless podman needs subuid/subgid ranges. Setting them here means a user
# created later on the running machine inherits working container support
# rather than discovering it is broken the first time they try.
if ! grep -q '^containers:' /etc/subuid 2>/dev/null; then
    echo 'containers:200000:65536' >> /etc/subuid
    echo 'containers:200000:65536' >> /etc/subgid
fi
