#!/bin/bash
# Merges the latest upstream (CachyOS/cachy-update) into this checkout,
# checks that the Manjaro renaming still covers everything, then builds,
# tests and installs the package (makepkg -sif). Nothing is pushed.
#
# Usage: tools/update-upstream.sh [--no-install] [REF]
#   REF          what to merge; by default upstream/main
#   --no-install merge and check only
#
# On conflicts it stops; fix them, commit, and run it again to go on.
# After it: log out and in, try it, then git push.
set -euo pipefail
cd "$(dirname "$0")/.."

upstream_url=https://github.com/CachyOS/cachy-update.git
pointer="> **This repository is the Manjaro build of CachyOS's cachy-update.** See [MANJARO.md](MANJARO.md) for what differs and how to build it."
install=1
ref=upstream/main
for arg in "$@"; do
    case $arg in
    --no-install) install=0 ;;
    -h | --help) sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) ref=$arg ;;
    esac
done

say() { printf '\n\033[1m==> %s\033[0m\n' "$*"; }

# README.md only differs by our pointer line: take upstream's, put the line back
resolve_readme() {
    git diff --name-only --diff-filter=U | grep -qx README.md || return 0
    git checkout --theirs -- README.md
    grep -qF "$pointer" README.md || printf '%s\n\n%s\n' "$pointer" "$(cat README.md)" > README.md
    git add README.md
    [ -n "$(git diff --name-only --diff-filter=U)" ] || git commit --no-edit >/dev/null
}

conflict_help() {
    cat <<'EOF'

The code is upstream's; ours are manjaro/, packaging/, tools/, MANJARO.md and
the line at the top of README.md. Keep upstream's side everywhere else. Then:
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
