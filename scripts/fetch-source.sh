#!/usr/bin/env bash
set -euo pipefail
ref="${1:-jdk7u351-ga}"
mkdir -p work
if [[ -e work/openjdk ]]; then
  echo 'work/openjdk already exists; refusing to silently reuse it' >&2
  exit 1
fi
# Preserve upstream line endings even when the Windows Git default is autocrlf.
git -c core.autocrlf=false clone --quiet --depth 1 --branch "$ref" https://github.com/openjdk/jdk7u.git work/openjdk
[[ -f work/openjdk/Makefile && -f work/openjdk/jaxp/build.xml && -d work/openjdk/jaxws/src ]] || {
  echo 'Upstream source appears incomplete' >&2; exit 1;
}
git -C work/openjdk rev-parse HEAD | tee work/upstream-commit.txt
