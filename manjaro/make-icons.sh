#!/bin/sh
# Manjaro fork: draws the notifier's tray and notification icons from the
# Manjaro logo installed by manjaro-icons (read at build time, not copied
# into this repository), under the names the notifier asks for:
#   cachy-update-{blue,light,dark}.svg                       up to date
#   cachy-update_updates-available-{blue,light,dark}[-cb].svg updates waiting
# "blue" is the coloured style (here: Manjaro green), "light" and "dark" are
# plain for dark and light panels, "-cb" marks the colour-blind badge.
# Usage: make-icons.sh OUTDIR [LOGO.svg]
set -eu
out=$1
logo=${2:-${MANJARO_LOGO:-/usr/share/icons/hicolor/scalable/apps/manjarolinux.svg}}
# The box below is measured on this version of the file; another version
# needs it measured again (the logo's path and transform are read from it).
known=8cc9ec23044e201d47fa9294cda812395f5bd889202f406c79063a158c292cbb
sum=$(sha256sum "$logo" | cut -d' ' -f1)
[ "$sum" = "$known" ] || { echo "make-icons.sh: $logo changed (sha256 $sum), check the logo box" >&2; exit 1; }

flat=$(tr '\n\t' '  ' <"$logo")
path=$(printf '%s' "$flat" | sed -E 's/.*<path[^>]* d="([^"]*)".*/\1/')
transform=$(printf '%s' "$flat" | sed -E 's/.*<g[^>]* transform="([^"]*)".*/\1/')
case $path in *'<'*|'') echo "make-icons.sh: no path in $logo" >&2; exit 1 ;; esac
case $transform in matrix*) ;; *) echo "make-icons.sh: no transform in $logo" >&2; exit 1 ;; esac

# the logo's box in the file's coordinates: 319.8 square from (29.07, 29.45)
# scaled to 21 of the icon's 24 units
box_x=29.07 box_y=29.45 scale=0.065666

icon() {  # name, logo colour, badge colour (empty: none)
    {
        printf '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">\n'
        printf '<g transform="translate(1.5 1.5) scale(%s) translate(-%s -%s)">' "$scale" "$box_x" "$box_y"
        printf '<g transform="%s"><path fill="%s" fill-rule="evenodd" d="%s"/></g></g>\n' "$transform" "$2" "$path"
        if [ -n "$3" ]; then
            printf '<circle cx="18.6" cy="18.6" r="4.4" fill="%s" stroke="#ffffff" stroke-width="1.2"/>\n' "$3"
        fi
        printf '</svg>\n'
    } >"$out/$1.svg"
}

mkdir -p "$out"
for style in blue light dark; do
    case $style in
    blue) colour='#35bfa4' ;;
    light) colour='#fcfcfc' ;;
    dark) colour='#232629' ;;
    esac
    icon "cachy-update-$style" "$colour" ''
    icon "cachy-update_updates-available-$style" "$colour" '#f67400'
    icon "cachy-update_updates-available-$style-cb" "$colour" '#1d99f3'
done
# the app icon of the menu entry and notifications
icon cachy-update_app-icon '#35bfa4' ''
