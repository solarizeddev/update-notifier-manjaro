#!/bin/bash
# Builds the Package Installer (a checkout of packageinstaller-manjaro, whose
# app the notifier opens) and this notifier with makepkg in a fresh Manjaro
# stable container, installs
# them and checks what a user gets at login: the autostarted tray, the timer,
# the icons, the update check, and the click opening the Package Installer on
# its Updates page (one window: a second start comes forward). The tray itself
# needs a panel and is checked on Plasma by hand. Screenshots and
# logs in OUTDIR. Needs docker.
# Usage: tools/test-manjaro.sh [OUTDIR]   (INSTALLER=path, default ../packageinstaller-manjaro)
# Behind a TLS-inspecting proxy: TEST_CA=/path/to/ca.pem; TEST_MIRROR=URL.
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
installer=$(cd "${INSTALLER:-$root/../packageinstaller-manjaro}" && pwd)
out=${1:-$(mktemp -d)}
mkdir -p "$out" && chmod 777 "$out"
ca=()
[ -n "${TEST_CA:-}" ] && ca=(-v "$TEST_CA:/run/test-ca.pem:ro")
docker run --rm --network host -e HTTPS_PROXY -e HTTP_PROXY -e https_proxy -e http_proxy -e TEST_MIRROR \
    "${ca[@]}" -v "$root:/src:ro" -v "$installer:/installer:ro" -v "$out:/out" manjarolinux/base:latest bash -c '
set -e
trap "echo failed at line \$LINENO, logs in the output directory" ERR
[ -e /run/test-ca.pem ] && { cp /run/test-ca.pem /etc/ca-certificates/trust-source/anchors/test-ca.crt; update-ca-trust; }
[ -n "$TEST_MIRROR" ] && printf "Server = %s\n" "$TEST_MIRROR" >/etc/pacman.d/mirrorlist
pacman -Sy --noconfirm --needed archlinux-keyring manjaro-keyring >/out/keyring.log 2>&1
pacman -Su --noconfirm --needed base-devel git sudo xorg-server-xvfb xdotool imagemagick ttf-dejavu dbus >/out/deps.log 2>&1
useradd -m tester
printf "%s\n" "tester ALL=(ALL) NOPASSWD: ALL" "Defaults env_keep += \"https_proxy HTTPS_PROXY http_proxy HTTP_PROXY\"" >/etc/sudoers.d/tester
mkdir /build && mkdir /build/installer /build/notifier
tar -C /installer --exclude=./build --exclude=./.git -cf - . | tar -C /build/installer -xf -
tar -C /src --exclude=./.git --exclude=./packaging/src --exclude=./packaging/pkg -cf - . | tar -C /build/notifier -xf -
chown -R tester /build
# makepkg -s installs the dependencies; the notifier needs the installer first
su tester -c "cd /build/installer/packaging && makepkg -si --noconfirm" >/out/makepkg-installer.log 2>&1
su tester -c "cd /build/notifier/packaging && makepkg -si --noconfirm" >/out/makepkg-notifier.log 2>&1

pacman -Qlq packageinstaller-manjaro-notifier-git >/out/notifier-files.txt
for f in /etc/xdg/autostart/arch-update-tray.desktop /usr/bin/arch-update /usr/lib/arch-update/arch-update-tray \
         /usr/share/applications/arch-update.desktop /usr/lib/systemd/user/arch-update.timer \
         /usr/lib/systemd/user/timers.target.wants/arch-update.timer \
         /usr/lib/systemd/user/arch-update.path /usr/lib/systemd/user/default.target.wants/arch-update.path \
         /usr/lib/systemd/user/arch-update.timer.d/manjaro.conf /usr/lib/systemd/user/arch-update.service.d/manjaro.conf \
         /usr/share/icons/hicolor/scalable/apps/cachy-update-blue.svg \
         /usr/share/icons/hicolor/scalable/apps/cachy-update_updates-available-blue.svg; do
    [ -e "$f" ] || { echo "missing: $f"; exit 1; }
done
grep -qx "Exec=packageinstaller-manjaro --updates" /usr/share/applications/arch-update.desktop
# the icons are the Manjaro logo, not the CachyOS one
grep -q "#35bfa4" /usr/share/icons/hicolor/scalable/apps/cachy-update-blue.svg
! sed "/^Icon=/d" /etc/xdg/autostart/arch-update-tray.desktop | grep -qi cachy
cp /usr/share/icons/hicolor/scalable/apps/cachy-update*.svg /out/

su tester -c "cd
  export XDG_RUNTIME_DIR=/tmp/xdg-tester; mkdir -p -m 700 \$XDG_RUNTIME_DIR
  arch-update --version >/out/version.txt
  # the check itself (no notification: no user systemd here)
  arch-update --check >/out/check.log 2>&1 || true
  cat ~/.local/state/arch-update/tray_icon >/out/tray_icon.txt
  cat ~/.local/state/arch-update/last_updates_check_packages >/out/updates.txt || true
  Xvfb :99 -screen 0 1280x860x24 >/dev/null 2>&1 & sleep 2
  export DISPLAY=:99
  dbus-run-session -- bash -c \"arch-update --tray; sleep 3\" >/out/tray.log 2>&1
  packageinstaller-manjaro >/out/run.log 2>&1 & pid=\$!; sleep 12
  import -window root /out/first.png
  # what the tray click runs: the open window comes forward on Updates
  timeout 10 packageinstaller-manjaro --updates >/out/second.log 2>&1; echo \"second start: \$?\" >>/out/second.log
  sleep 3
  import -window root /out/updates.png
  kill -0 \$pid
  [ \$(pgrep -c packageinstall) -eq 1 ]"
# There is no panel here: the applet starts and gets as far as looking for one
# (on Plasma, the tray is checked by hand).
grep -q "StatusNotifierWatcher" /out/tray.log || { echo "the tray applet did not start"; exit 1; }
echo "all checks passed"
'
echo "logs and screenshots in $out"
