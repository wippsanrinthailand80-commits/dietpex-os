# dietpex OS

A trimmed-down Ubuntu — a single-line installer plus a small set of scripts
that strip the bloat off a stock Ubuntu (or Debian-family) system so it boots
faster and uses less RAM, disk and CPU, and replaces the default UI with a
lightweight XFCE desktop.

dietpex is not a new kernel or a separate distro — it runs on top of a normal
Ubuntu install and surgically removes the services and packages you almost
never need on a lean workstation, server or appliance.

## Install (single line)

```bash
curl -fsSL https://raw.githubusercontent.com/wippsanrinthailand80-commits/dietpex-os/main/install.sh | sudo bash
```

The installer detects your environment and offers a menu:

1. **Full install** — dietpex trim + XFCE UI (optionally removes GNOME)
2. **Trim only** — disable unnecessary services, purge bloatware
3. **Install XFCE UI only**
4. **Set up dual-boot GRUB menu** — the "two OS" boot screen at startup
5. **Install inside Windows (WSL2)** — real Ubuntu on Windows, no partitions
6. **Create a bootable USB** — for a full native install with a true Linux UI

Or skip the menu with flags:

```bash
sudo bash install.sh --full
sudo bash install.sh --trim-only
sudo bash install.sh --dual-boot
sudo bash install.sh --windows-wsl
sudo bash install.sh --make-usb /dev/sdb
sudo bash install.sh --thai          # Thai fonts + locale (no "tofu" boxes)
sudo bash install.sh --thai-noto     # same, plus Noto Sans Thai (better on Google)
sudo bash install.sh --lang th       # Thai UI
```

> **Security note:** piping a script from the internet into bash is risky.
> Review the script first, or clone the repo and run `install.sh` locally.

## What it does

1. **Disables (masks) ~42 unnecessary systemd services**, so they can never be
   started again — not even by package upgrades. Notable victims:
   - `snapd` (snap auto-updates, loop mounts)
   - `cups` / `cups-browsed` (printing)
   - `bluetooth`, `ModemManager` (radio peripherals)
   - `avahi-daemon` (mDNS discovery)
   - `whoopsie` / `apport` / `kerneloops` (crash reporting)
   - `apt-daily*` / `unattended-upgrades` (background apt automation)
   - `fwupd` (firmware update daemon)
   - `smartd`, `packagekit` and more
   - Deliberately kept: `udisks2` (so USB drives still mount in the file
     manager), `thermald` (laptop cooling) and `rtkit` (audio real-time
     priority).

2. **Optionally purges bloatware** (included in every install path):
   LibreOffice, Thunderbird, games, media players, photo apps, backup tools,
   remote-desktop clients — over 50 packages/patterns.

3. **Installs a lightweight UI** — XFCE (`xfce4`, `xfce4-terminal`,
   `xfce4-goodies`, `lightdm`), set as the default graphical session.
   Optionally removes GNOME with `--purge-gnome`.

4. **Cleans up** — `apt` autoremove/clean, trimmed systemd journal.

## Languages

English and Thai are built in. Language is auto-detected from the locale
(`th_TH.UTF-8` → Thai) and can be forced with `--lang th` / `--lang en`.
Add more languages by dropping a file in `lang/` that defines `msg()`.

## Thai rendering (no "lost" Thai)

Websites and Google often show empty boxes when no Thai font is installed and
the `th_TH` locale is missing. `install.sh --thai` (menu option 7) fixes this:

- installs Thai-capable fonts (`fonts-thai-tlwg` set + Noto Sans Thai + emoji)
- writes a fontconfig rule so Thai text is rendered by Noto Sans Thai —
  this fixes **floating above-vowels** (ิ ี ึ ื ำ) and **submerged
  below-vowels** (ุ ู) that appear when a Latin font handles Thai marks
- generates the `th_TH.UTF-8` locale (falls back to `localedef` where
  `locale-gen` is missing)
- refreshes the fontconfig cache so browsers pick up the fonts

Thai support is also included in the **full install** and **WSL2** paths.

## Bootable USB

`install.sh --make-usb /dev/sdX` (menu option 6) writes the current Ubuntu
24.04 desktop ISO to a USB device. The ISO URL is resolved live from the
Ubuntu releases page so it never goes stale (`helpers/flashdrive.sh resolve`
prints the URL that would be used). Safety rails:

- refuses to write a device that is the system disk or has mounted partitions
- checks the device is large enough for the ISO before writing
- asks for explicit `YES` confirmation (and shows the device first)

## Dual boot ("two OS")

Run `install.sh --dual-boot` (or menu option 4) inside your Ubuntu system. It
installs `os-prober` and regenerates the GRUB menu so every OS on the machine
appears in a "choose your OS" screen at boot. For a full second-OS install,
create a bootable USB (option 6) and choose "Install Ubuntu alongside".

## Windows (WSL2)

Run `install.sh --windows-wsl` (or menu option 5) inside WSL2. It trims the
WSL Ubuntu and installs XFCE, which renders through WSLg on Windows 11. Start
the desktop later with `startxfce4`. If WSL has systemd disabled, the service
masking phase is skipped automatically (purge still runs).

## Testing

CI runs automatically on every push (`.github/workflows/ci.yml`):

- `tests/unit.sh` — pure-bash helper tests (list parsing, glob matching,
  protected-package handling). Run locally: `bash tests/unit.sh`
- `tests/integration.sh` — real trim in a systemd-enabled Ubuntu container:
  verifies services are actually masked, bloat is actually purged, protected
  packages survive, and dry-run is non-destructive. Also verifies the USB
  writer (loop device), that it refuses the system disk, that `udisks2` stays
  unmasked, XFCE boots as the default session, and Thai rendering works.
- `shellcheck` + `bash -n` on every script.

## Customizing

Edit the lists in `config/`:

- `services-disable.list` — systemd unit names to stop/disable/mask
- `packages-remove.list` — packages to purge (glob patterns like
  `libreoffice-*` are supported)
- `packages-protect.list` — packages that must never be purged

## Restoring

The scripts do **not** make an automatic backup, but everything is reversible:

```bash
sudo systemctl unmask snapd.service      # per service, as needed
sudo apt install --reinstall <package>   # reinstall purged packages
sudo update-alternatives --config x-session-manager  # switch back to GNOME
```

## Project layout

```
dietpex-os/
├── install.sh                  # single-line installer (menu + flags)
├── dietpex.sh                  # core trimmer (services + purge)
├── helpers/
│   ├── lib.sh                  # shared library (detect, apt, i18n)
│   ├── ui.sh                   # XFCE UI install (+ optional GNOME removal)
│   ├── i18n.sh                 # Thai fonts + locale support
│   ├── dualboot.sh             # GRUB dual-boot menu setup
│   ├── windows-wsl.sh          # WSL2 install path
│   └── flashdrive.sh           # bootable USB creator
├── lang/
│   ├── en.sh                   # English messages
│   └── th.sh                   # Thai messages
├── config/
│   ├── services-disable.list
│   ├── packages-remove.list
│   └── packages-protect.list
├── tests/
│   ├── unit.sh
│   └── integration.sh
└── .github/workflows/ci.yml
```

## Safety notes

- Always review what will change first: `sudo ./dietpex.sh --dry-run --purge`.
- The protected list shields core packages (`apt`, `systemd`,
  `linux-firmware`, `ubuntu-minimal`, …) from accidental removal.
- Missing services/packages are skipped silently.
- CI exercises the real trim inside a disposable Ubuntu container.
