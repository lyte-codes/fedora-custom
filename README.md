# fedora-custom

A custom Fedora for an x86_64 PC, built as a container image and booted as an
operating system (`bootc`).

## Why it is shaped this way

**Low overhead** starts with the base. `fedora-bootc` ships no desktop, no
office suite, no media stack — you add to a minimal system rather than deleting
from a full one. `install_weak_deps=False` in `overlay/etc/dnf/dnf.conf` then
stops every `dnf install` dragging in "Recommends" you never asked for, which
is the main way Fedora systems get quietly fat.

**Modular** means one concern per file in `modules/`, and a named preset in
`profiles/` that says which ones to use:

| Profile | Headed | Size | What it is |
|---|---|---|---|
| `desktop` | yes | 2.89 GB | **the default** — Xfce + Firefox |
| `desktop-plasma` | yes | 3.71 GB | same, with KDE Plasma |
| `minimal` | no | 1.98 GB | boots, networks, takes ssh |
| `normal` | no | 2.13 GB | + a terminal worth using |
| `max` | no | 2.38 GB | + compilers and containers |

```bash
podman build --build-arg PROFILE=desktop .          # the default
podman build --build-arg PROFILE=desktop-plasma .   # Plasma instead of Xfce
```

Stock `fedora-bootc:44` is 1.98 GB, so a full working desktop costs **910 MB
on top of Fedora itself**. For comparison, installing the `xfce-desktop-environment`
or `kde-desktop` group instead of naming packages individually would have been
several gigabytes more.

**Turning an app off is deleting a line from a profile.** Adding a capability
is adding a file to `modules/` and a line to whichever profiles want it. You
should never need to edit the `Containerfile` again.

For a one-off that does not fit a preset, `MODULES` bypasses the profile:

```bash
podman build --build-arg MODULES="00-core 20-dev" .   # dev tools, no shell extras
```

`max` is the biggest, not the best. If you are not compiling on this machine,
`normal` boots faster and updates quicker.

## Layout

```
Containerfile                 base image, module + driver runner, cleanup
profiles/                     which modules each preset turns on
modules/00-core.sh            networking, ssh, journal limits — the floor
modules/10-shell.sh           terminal tooling
modules/20-dev.sh             containers + compilers (headless profiles only)
modules/30-desktop-xfce.sh    Xfce, Wayland-capable-ish, PipeWire, fonts
modules/30-desktop-plasma.sh  KDE Plasma on Wayland — the alternative
modules/40-flatpak.sh         Flatpak + first-boot app install + daily updates
drivers/amd.sh                GPU userspace — see drivers/README.md
drivers/intel.sh
drivers/nvidia.sh             scaffold only; proprietary NVIDIA is the hard case
drivers/firmware/             drop custom firmware blobs here
overlay/                      files copied verbatim into the image
.github/workflows/build.yml   builds on x86_64 runners, pushes to ghcr.io
```

Drivers are a separate argument from modules, because they change for a
different reason — modules are what the machine *does*, drivers are what it
*is*:

```bash
podman build --build-arg MODULES="00-core 10-shell" --build-arg DRIVERS="amd" .
```

`DRIVERS` defaults to empty, which builds and boots fine. You are not blocked
on picking a GPU.

## Building

Pushing to `main` builds and publishes `ghcr.io/<you>/fedora-custom:latest`.
Use the **Run workflow** button to build a one-off with a different module list.

Builds happen on GitHub's runners because they are x86_64 and every machine
here is ARM. Emulating x86 locally works but takes hours per build.

## Installing on the PC

You need an installable image once; after that the machine updates itself from
the registry.

```bash
# On any x86_64 Linux box with podman, produce a bootable ISO:
sudo podman run --rm -it --privileged \
  -v ./output:/output \
  -v /var/lib/containers/storage:/var/lib/containers/storage \
  quay.io/centos-bootc/bootc-image-builder:latest \
  --type iso ghcr.io/<you>/fedora-custom:latest
```

Then, on the installed machine:

```bash
sudo bootc upgrade      # fetch the newest image and stage it
sudo reboot             # boot into it
sudo bootc rollback     # go back if it misbehaves
```

## The tradeoff to understand before committing

The running system is **immutable**. `dnf install` does not persist across
reboots the way it does on ordinary Fedora. To add a package you edit a module,
push, and `bootc upgrade`.

What you get for that: updates are atomic, and a bad one is one `bootc rollback`
away instead of a rescue USB. What you give up: casually installing something
right now. `rpm-ostree install` exists as an escape hatch and needs a reboot.

If you find yourself fighting this, the answer is usually a container or a
toolbox, not layering onto the host.

## Notes

- Pinned to Fedora **44** (current stable). 45 is rawhide. Bump
  `FEDORA_VERSION` in the `Containerfile` deliberately, not automatically.
- `bootc container lint` runs at the end of every build and catches problems
  that would otherwise only appear at boot.
- Image size prints in the build log — watch it for regressions.
