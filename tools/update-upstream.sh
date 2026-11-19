#!/bin/bash
# Merges the latest upstream (CachyOS/cachy-update) into this checkout,
# checks that the Manjaro renaming still covers everything, then builds,
# tests and installs the package (makepkg -sif). Nothing is pushed.
#
# Usage: tools/update-upstream.sh [--no-install] [--no-logo] [REF]
#   REF          what to merge; by default upstream/main
#   --no-install merge and check only
#   --no-logo    build with a generic icon in place of the Manjaro logo
#                (same as NO_MANJARO_LOGO=1 makepkg -sif)
#
# On conflicts it stops; fix them, commit, and run it again to go on.
# After it: log out and in, try it, then git push.
set -euo pipefail
self=$(readlink -f "$0")
cd "$(dirname "$self")/.."

upstream_url=https://github.com/CachyOS/cachy-update.git
install=1
ref=upstream/main
for arg in "$@"; do
    case $arg in
    --no-install) install=0 ;;
    --no-logo) export NO_MANJARO_LOGO=1 ;;
    -h | --help) sed -n '2,14p' "$self" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) ref=$arg ;;
    esac
done

# README.md is manjaro/README-header.md followed by upstream's README without
# its title and its logo (the first centred picture): on a conflict take
# upstream's and put the header back.
readme_with_header() {
    { cat manjaro/README-header.md
      sed '1{/^# /d}' README.md | sed '/./,$!d' \
          | awk '!done && /^<p align="center">/ {skip=1} skip {if (/<\/p>/) {skip=0; done=1}; next} {print}' \
          | sed '/./,$!d'; } > README.md.new
    mv README.md.new README.md
}

say() { printf '\n\033[1m==> %s\033[0m\n' "$*"; }

# README.md: upstream's, with our header put back
resolve_readme() {
    git diff --name-only --diff-filter=U | grep -qx README.md || return 0
    git checkout --theirs -- README.md
    readme_with_header
    git add README.md
    [ -n "$(git diff --name-only --diff-filter=U)" ] || git commit --no-edit >/dev/null
}

conflict_help() {
    cat <<'EOF'

The code is upstream's; ours are manjaro/, packaging/, tools/, MANJARO.md and
the header of README.md (manjaro/README-header.md). Keep upstream's side everywhere else. Then:
  git add <files> && git commit       (or: git merge --abort to undo)
and run this script again: it goes on with the checks and the install.
EOF
}

if ! git diff --quiet || ! git diff --cached --quiet; then
    echo "Uncommitted changes: commit or stash them first." >&2
    exit 1
fi

git remote get-url upstream >/dev/null 2>&1 || git remote add upstream "$upstream_url"
say "Fetching upstream"
git fetch --quiet --tags upstream
git rev-parse --verify --quiet "$ref^{commit}" >/dev/null || { echo "Unknown ref: $ref" >&2; exit 1; }

count=$(git rev-list --count "HEAD..$ref")
if [ "$count" -gt 0 ]; then
    say "$count new upstream commit(s) in $ref"
    git log --oneline --no-merges -n 40 "HEAD..$ref"
    before=$(git rev-parse HEAD)
    say "Merging $ref"
    git merge --no-edit -m "Merge upstream ${ref#upstream/}" "$ref" || resolve_readme
    # still merging, or no merge happened
    if git rev-parse -q --verify MERGE_HEAD >/dev/null || [ "$(git rev-parse HEAD)" = "$before" ]; then
        say "Conflicts"
        git diff --name-only --diff-filter=U | sed 's/^/  /'
        conflict_help
        exit 1
    fi
elif git log -1 --format=%s | grep -q '^Merge upstream' && git rev-parse -q --verify HEAD^2 >/dev/null; then
    say "Continuing after the merge of $ref"
else
    say "Already up to date with $ref"
    exit 0
fi

say "Checking the Manjaro renaming on a copy"
# rebrand.sh stops on a CachyOS name it does not cover, and make-icons.sh on a
# changed Manjaro logo file: then fix manjaro/, not upstream's files
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
tar --exclude=./.git --exclude=./packaging -cf - . | tar -C "$tmp" -xf -
manjaro/rebrand.sh "$tmp"
echo "  renaming complete"

if [ "$install" -eq 1 ]; then
    say "Building, testing and installing (makepkg -sif)"
    (cd packaging && makepkg -sif --noconfirm)
fi

say "Done: $ref"
cat <<'EOF'
Next: log out and in (tray icon, a click opens Updates), then
  git push
EOF
