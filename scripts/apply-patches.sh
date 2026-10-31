#!/usr/bin/env bash
set -euo pipefail
src="${1:?Pass the OpenJDK source directory}"
[[ -d "$src/.git" ]] || { echo "Not a Git working tree: $src" >&2; exit 1; }
shopt -s nullglob
patches=(patches/security/*.patch patches/build/*.patch)
mkdir -p work
: > work/applied-patches.txt
for patch in "${patches[@]}"; do
  echo "Applying $patch"
  git -C "$src" apply --check "$(realpath "$patch")"
  git -C "$src" apply "$(realpath "$patch")"
  printf '%s\n' "$patch" >> work/applied-patches.txt
done
printf 'Applied %d patch(es)\n' "${#patches[@]}"
