# drivers/

Hardware enablement, kept separate from `modules/` because it changes for a
different reason: modules are what you want the machine to *do*, drivers are
what the machine *is*. Swap the GPU and exactly one build argument changes.

## Using them

```bash
podman build --build-arg DRIVERS="amd"           .
podman build --build-arg DRIVERS="intel"         .
podman build --build-arg DRIVERS="nvidia"        .
podman build --build-arg DRIVERS=""              .   # none — the default
```

Leave it empty until you know what you are putting in the machine. An image
with no GPU driver still boots fine to a console; you are not blocked on the
decision.

## What is actually needed, by vendor

Most hardware needs nothing. Linux ships the driver in the kernel and the
firmware in `linux-firmware`, and it simply works. The list of things that
genuinely need help is short.

| GPU | Kernel driver | What these scripts add |
|---|---|---|
| **AMD** | `amdgpu`, in-tree | Mesa + Vulkan userspace, VA-API |
| **Intel** | `i915`/`xe`, in-tree | Mesa + Vulkan userspace, VA-API |
| **NVIDIA (nouveau)** | in-tree | nothing — works out of the box, slowly |
| **NVIDIA (proprietary)** | out-of-tree | a great deal — see below |

## The NVIDIA problem, stated plainly

The proprietary NVIDIA driver is not a package you install; it is a kernel
module that must be compiled against the **exact kernel** in the image. That
makes it fundamentally different from everything else here:

- The build needs RPM Fusion and `akmods`, in a stage that knows the kernel version.
- Every Fedora kernel bump means the module rebuilds, so a routine update can
  break your display driver.
- Secure Boot requires the module to be signed with a key you enrol in firmware.

`nvidia.sh` documents the approach and is **deliberately not a working
one-liner** — pretending otherwise would hand you a build that fails at 2am.
If you land on NVIDIA, budget an evening for it and expect to iterate.

If the choice is still open and you want a quiet life: **AMD**. In-tree driver,
no out-of-tree module, no Secure Boot signing, nothing to break on a kernel
update. Intel integrated graphics is equally painless.

## firmware/

Drop binary firmware blobs in `firmware/` and they are copied to
`/usr/lib/firmware/` in the image. You rarely need this — `linux-firmware`
covers nearly everything — but it is here for the odd Wi-Fi card or capture
device that ships its own.

Anything in there is committed to a public repo, so do not put redistributable-
restricted blobs in it.
