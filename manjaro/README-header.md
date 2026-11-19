# update-notifier-manjaro

> Community project, not affiliated with or endorsed by Manjaro GmbH & Co. KG
> or CachyOS. The Manjaro name and logo are trademarks of Manjaro GmbH & Co. KG.

A tray icon for [Manjaro](https://manjaro.org) that shows when updates are
waiting (packages, AUR, Flatpak). It is a port of
[CachyOS's cachy-update](https://github.com/CachyOS/cachy-update).

<p align="center"><img src="manjaro/icon.svg" width="128" alt="The tray icon: the Manjaro logo with a dot while updates wait"></p>

Install: first [packageinstaller-manjaro](https://github.com/solarizeddev/packageinstaller-manjaro),
then clone this repo and run `cd packaging && makepkg -sif`. Log out and in to get the tray.

- [MANJARO.md](MANJARO.md): what differs from CachyOS's version, building, merging upstream.

---

*Below is CachyOS's README, without its logo and screenshots. In this build
"Cachy-Update" is "Manjaro Update", and a click opens the Package Installer
instead of a terminal.*

