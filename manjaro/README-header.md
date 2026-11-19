# update-notifier-manjaro

> Community project, not affiliated with or endorsed by Manjaro GmbH & Co. KG
> or CachyOS. The Manjaro name and logo are trademarks of Manjaro GmbH & Co. KG.

A tray icon for [Manjaro](https://manjaro.org) that shows when updates are
waiting (packages, AUR, Flatpak). It is a port of
[CachyOS's cachy-update](https://github.com/CachyOS/cachy-update).

<p align="center"><img src="manjaro/icon.svg" width="128" alt="The tray icon: the Manjaro logo with a dot while updates wait"></p>

Install: first [packageinstaller-manjaro](https://github.com/solarizeddev/packageinstaller-manjaro),
then clone this repo and run `cd packaging && makepkg -sif`. Log out and in to get the tray.

Merge new CachyOS changes: `tools/update-upstream.sh` merges them, checks the
Manjaro renaming, then builds and installs. Nothing is pushed.

- [MANJARO.md](MANJARO.md): what differs from CachyOS's version.

---

*Below is CachyOS's README, without its logo and screenshots. Skip its
Installation section, and the enable commands under Usage: the package above
starts the tray and the update checks for every user. In this build
"Cachy-Update" is "Manjaro Update", the command is `arch-update` (not
`cachy-update`), and a click opens the Package Installer instead of a terminal.*

