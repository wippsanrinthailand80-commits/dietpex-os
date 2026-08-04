# dietpex OS

A trimmed-down Ubuntu — a small, opinionated post-install script that strips
the bloat off a stock Ubuntu (or Debian-family) system so it boots faster and
uses less RAM, disk and CPU. "dietpex" = **diet** + **p**ainless **ex**cess
removal.

dietpex is not a new kernel or a separate distro — it runs on top of a normal
Ubuntu install and surgically removes the services and packages you almost
never need on a lean workstation, server or appliance.

## What it does

1. **Disables (masks) ~46 unnecessary systemd services**, so they can never be
   started again — not even by package upgrades. Notable victims:
   - `snapd` (snap auto-updates, loop mounts)
   - `cups` / `cups-browsed` (printing)
   - `bluetooth`, `ModemManager` (radio peripherals)
   - `avahi-daemon` (mDNS discovery)
   - `whoopsie` / `apport` / `kerneloops` (crash reporting)
   - `apt-daily*` / `unattended-upgrades` (background apt automation)
   - `fwupd` (firmware update daemon)
   - `udisks2`, `smartd`, `packagekit`, `rtkit` and more

2. **Optionally purges bloatware** (`--purge`) with a curated list:
   - LibreOffice, Thunderbird, games, media players, photo apps, backup tools,
     remote-desktop clients, etc. — over 50 packages/patterns.

3. **Cleans up** — `apt` autoremove/clean, trimmed systemd journal.

## Requirements

- Ubuntu 18.04+ (or another systemd-based Debian-family distro)
- `systemd`, `apt` and `dpkg-query`
- root access

## Quick start

```bash
# 1. Clone or copy the project
git clone <this-repo> dietpex-os
cd dietpex-os

# 2. Preview what would change (safe, makes no modifications)
sudo ./dietpex.sh --dry-run --purge

# 3. Apply the trim (services only)
sudo ./dietpex.sh

# 4. Apply the full trim, including bloatware removal
sudo ./dietpex.sh --purge

# 5. Reboot
sudo reboot
```

## Options

| Flag | Effect |
| --- | --- |
| `--purge` | Also remove bloatware packages from `config/packages-remove.list` |
| `--dry-run` | Report only; make no changes to the system |
| `--no-clean` | Skip `apt` autoremove / cache and journal cleanup |
| `--snap` | Keep the snap ecosystem (don't mask `snapd`) |
| `--keep-list FILE` | Use an alternate services list |
| `--purge-list FILE` | Use an alternate packages list |
| `-q, --quiet` | Suppress informational output |
| `-h, --help` | Show usage |

## Customizing

Edit the lists in `config/`:

- `services-disable.list` — systemd unit names to stop/disable/mask (one per
  line, `#` for comments).
- `packages-remove.list` — packages to purge (glob patterns like
  `libreoffice-*` are supported).
- `packages-protect.list` — packages that must never be purged, even if listed.

## Restoring

The script does **not** make an automatic backup, but everything is reversible:

```bash
# Unmask services (iterate the list manually if needed)
sudo systemctl unmask snapd.service
sudo systemctl enable --now snapd.service

# Reinstall purged packages
sudo apt install --reinstall <package>
```

## Project layout

```
dietpex-os/
├── dietpex.sh                  # main installer / trimmer script
├── config/
│   ├── services-disable.list   # systemd units to disable + mask
│   ├── packages-remove.list    # bloatware to purge (--purge)
│   └── packages-protect.list   # never purge these
└── README.md
```

## Safety notes

- Always run `--dry-run` first on a system you care about.
- The protected list shields core packages (`apt`, `systemd`, `linux-firmware`,
  `ubuntu-minimal`, …) from accidental removal.
- If a service or package isn't installed, it is skipped silently.
- Tested targets: Ubuntu Desktop/Server. The current environment (Debian 13)
  has no `systemd`, so full end-to-end verification must be done on a real
  Ubuntu host.
