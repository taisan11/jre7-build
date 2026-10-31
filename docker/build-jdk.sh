#!/usr/bin/env bash
set -euo pipefail

src=/work/openjdk
out=/work/out
boot=/usr/lib/jvm/java-6-openjdk-amd64

[[ -f "$src/Makefile" ]] || { echo 'Missing OpenJDK source tree' >&2; exit 1; }
[[ -x "$boot/bin/javac" ]] || { echo "Missing JDK 6 bootstrap compiler: $boot" >&2; exit 1; }

# OpenJDK 7's makefiles rely on a controlled, classic build environment.
export LANG=C LC_ALL=C
unset JAVA_HOME CLASSPATH _JAVA_OPTIONS JAVA_TOOL_OPTIONS || true
export ALT_BOOTDIR="$boot"
export ALT_FREETYPE_HEADERS_PATH=/usr/include/freetype2
export ALT_FREETYPE_LIB_PATH=/usr/lib/x86_64-linux-gnu
export CC=/usr/bin/gcc-4.8 CXX=/usr/bin/g++-4.8
export HOTSPOT_BUILD_JOBS="${BUILD_JOBS:-2}"
export PARALLEL_COMPILE_JOBS="${BUILD_JOBS:-2}"
export NO_DOCS=true

mkdir -p "$out"
cd "$src"

echo '== Toolchain =='
"$boot/bin/java" -version
"$boot/bin/javac" -version
"$CC" --version | head -1
make --version | head -1

echo '== Building OpenJDK 7u =='
# No network downloads from the old Ant build system. JAXP/JAXWS sources are
# already present in the consolidated OpenJDK Git repository.
make sanity ALT_BOOTDIR="$ALT_BOOTDIR"
make -j"${BUILD_JOBS:-2}" all ALLOW_DOWNLOADS=false \
  ALT_BOOTDIR="$ALT_BOOTDIR" HOTSPOT_BUILD_JOBS="$HOTSPOT_BUILD_JOBS"

jdk_image="$(find "$src/build" -type d -name j2sdk-image -print -quit)"
[[ -n "$jdk_image" && -x "$jdk_image/bin/java" && -x "$jdk_image/bin/javac" ]] || {
  echo 'Build finished, but no complete j2sdk-image was produced' >&2
  exit 1
}

# Test compiler, runtime, basic SSL setup, and AWT class loading without X11.
mkdir -p /tmp/java7-smoke
"$jdk_image/bin/javac" -source 7 -target 7 -d /tmp/java7-smoke /work/tests/SmokeTest.java
"$jdk_image/bin/java" -Djava.awt.headless=true -cp /tmp/java7-smoke SmokeTest
"$jdk_image/bin/java" -version

echo "$jdk_image" > "$out/jdk-image-path.txt"
