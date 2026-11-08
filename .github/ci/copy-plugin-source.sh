#!/usr/bin/env bash
# Copies what a checkout ships, the files git tracks, so a local run tests what CI tests. A
# directory that is no checkout, such as a copy this script made, is copied whole without build
# output or installed CLIs. A marketplace install copies the whole plugin root, and node_modules
# alone is most of a gigabyte.
#
#   copy-plugin-source.sh <repo-root> <dest>
set -euo pipefail

src=${1:?usage: copy-plugin-source.sh <repo-root> <dest>}
dest=${2:?usage: copy-plugin-source.sh <repo-root> <dest>}

mkdir -p "$dest"
if [ -e "$src/.git" ]; then
  git -C "$src" ls-files -z | tar -C "$src" --null -T - -cf - | tar -C "$dest" -xf -
else
  tar -C "$src" --exclude=./target --exclude=./test-app/target \
    --exclude=./.github/ci/node_modules -cf - . | tar -C "$dest" -xf -
fi
