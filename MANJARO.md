# Update notifier for Manjaro

CachyOS's update notifier, [cachy-update](https://github.com/CachyOS/cachy-update)
(GPL-3.0, a fork of [arch-update](https://github.com/Antiz96/arch-update)),
built for Manjaro and for the
[Package Installer for Manjaro](https://github.com/solarizeddev/packageinstaller-manjaro)
(CachyOS's package installer 2.0, built for Manjaro).

The code is upstream's, unchanged: the Manjaro build renames it while
packaging (`manjaro/rebrand.sh`), so each upstream release merges cleanly.

## What a Manjaro user gets

- At login, for every user and desktop (`/etc/xdg/autostart`), a tray icon:
  the Manjaro logo, with a dot while updates are waiting. Its menu lists them
  (packages, AUR with paru, Flatpak).
- A systemd user timer, on for every user (not for system users such as the
  display manager), checks 2 to 7 minutes after login and then daily, with
  `checkupdates` (no root, the system databases are not touched), and sends a
  notification when the list changes. It checks again whenever packages
  change (`arch-update.path`), so the icon is right after updating with the
  Package Installer, pacman or pamac. AUR updates are counted through paru
  only, the AUR helper the Package Installer builds with.
- A click on the icon, or "Open the Package Installer" in the notification,
  opens the Package Installer on its Updates page; if it is already open,
  that window comes forward.
- The icons are drawn at build time from the logo `manjaro-icons` installs
  (`manjaro/make-icons.sh`); the build stops if that file changes, since the
  logo's box is measured on it.

A user who does not want it:

```bash
systemctl --user mask arch-update.timer arch-update.path
mkdir -p ~/.config/autostart && printf '[Desktop Entry]\nHidden=true\n' > ~/.config/autostart/arch-update-tray.desktop
```

On Manjaro KDE, pamac's own tray icon may show the same updates; turn one of
them off in the same way (`pamac-tray.desktop`). Settings:
`~/.config/arch-update/arch-update.conf` (see `man arch-update.conf`).

The `arch-update` command is kept as upstream's: run in a terminal, it
updates interactively and shows the Arch Linux news, not Manjaro's
announcements.

## Without the Manjaro logo

`NO_MANJARO_LOGO=1 makepkg -sif` (or `tools/update-upstream.sh --no-logo`) draws
the tray icons as a generic box with a down arrow instead of the Manjaro logo,
and needs no logo file. For when Manjaro asks us not to use the logo; the
Package Installer has the same switch.

## Build

```bash
cd packaging && makepkg -sif
```

It needs `packageinstaller-manjaro` installed first (its `packaging/`).
Log out and in again to get the tray.

## Merging an upstream release

```bash
tools/update-upstream.sh
```

It fetches upstream (adding the `upstream` remote the first time), merges
`upstream/main`, checks on a copy that the renaming still covers everything
(it stops on a CachyOS name it does not know, or on a changed Manjaro logo
file: fix `manjaro/` then), then builds, tests and installs with
`makepkg -sif`. It does not push: log out and in, check the tray icon and that
a click opens the Updates page, then `git push`. `--no-install` stops after
the checks. A conflict in README.md is resolved by itself (upstream's README under our header, `manjaro/README-header.md`); for
any other, keep upstream's side, commit, and run it again.

`INSTALLER=../packageinstaller-manjaro tools/test-manjaro.sh` builds both
packages in a clean Manjaro container and checks them together (needs docker).


## What differs from upstream

| Where | What |
|---|---|
| `manjaro/rebrand.sh` | Run in `prepare()` on a copy: "Cachy-Update" → "Manjaro Update", "CachyOS" → "Manjaro", "Run Cachy-Update" → "Open the Package Installer" |
| `manjaro/arch-update.desktop` | Replaces the desktop file the tray and notification launch: the Package Installer's Updates page instead of a terminal |
| `manjaro/make-icons.sh` | The tray and notification icons from the Manjaro logo |
| `manjaro/arch-update.path`, `manjaro/no-system-users.conf` | A check after every package change; no checks for system users |
| `manjaro/rebrand.sh` (also) | The first check 2 to 7 minutes after login (upstream: up to an hour); AUR updates through paru only |
| `packaging/PKGBUILD`, `tools/test-manjaro.sh`, this file | The package and its test |

The Manjaro name and logo are trademarks of Manjaro GmbH & Co. KG; the logo
is not copied into this repository, it is read from `manjaro-icons` at build
time.
