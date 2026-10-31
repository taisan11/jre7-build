#!/usr/bin/env bash
# Run under Cygwin, with vcvarsall.bat already called by run-build.cmd.
set -euo pipefail

repo="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$repo"
mkdir -p work/logs out

: "${BOOT_JDK_DIR:?Windows JDK6 bootstrap home required}"
: "${LEGACY_ANT_HOME:?Windows Ant 1.9 home required}"
: "${VCVARSALL:?Visual Studio C++ environment required}"

# MSVC's PATH/INCLUDE/LIB come from vcvarsall.bat (Windows cmd parent).
# Windows paths exported here are converted for Cygwin build tools.
boot_dir="$(cygpath -m "$BOOT_JDK_DIR")"
export ALT_BOOTDIR="$boot_dir"
export ALT_JDK_IMPORT_PATH="$boot_dir"
export ANT_HOME="$(cygpath -m "$LEGACY_ANT_HOME")"
export ARCH_DATA_MODEL=64
export BUILD_JDK=true
export HOTSPOT_BUILD_JOBS="${BUILD_JOBS:-2}"
export PARALLEL_COMPILE_JOBS="${BUILD_JOBS:-2}"
export NO_DOCS=true
export SKIP_COMPARE_IMAGES=true
export SKIP_DEBUG_BUILD=true
export SKIP_FASTDEBUG_BUILD=true
export LANG=C LC_ALL=C
unset JAVA_HOME CLASSPATH JAVA_TOOL_OPTIONS _JAVA_OPTIONS || true

# Avoid Git-for-Windows GNU utilities and newer host Java/Ant.
export PATH="$repo/work/cygwin-tools:/usr/local/bin:/usr/bin:/bin:${PATH}"

set -o pipefail
{
  echo '== Windows Java 7 native build: EXPERIMENTAL =='
  echo 'Host: GitHub-hosted windows-2022 with preinstalled MSVC'
  echo 'Warning: OpenJDK 7u351 Windows build was designed around VS2010 (v100).'
  echo 'VS2022 (v143) is not source-compatible without further patches.'
  echo 'Any failure must be fixed in the build patches; do not repackage Java 6 or Java 8.'
  echo '== Toolchain =='
  "$(cygpath -u "$BOOT_JDK_DIR")/bin/java" -version
  "$(cygpath -u "$BOOT_JDK_DIR")/bin/javac" -version
  command -v ant
  ant -version
  command -v make
  make --version | head -1
  command -v cl.exe
  cl.exe 2>&1 | head -6 || true
  echo '== Source sanity =='
  test -f work/openjdk/Makefile
  cd work/openjdk
  # JDK 7 forest uses legacy makefiles, NOT configure.
  # Current make / compiler may produce errors; fail instead of shipping fake ZIPs.
  make sanity ALT_BOOTDIR="$ALT_BOOTDIR" ALLOW_DOWNLOADS=false
  echo '== Full native JDK build =='
  make -j"${BUILD_JOBS:-2}" all ALT_BOOTDIR="$ALT_BOOTDIR" \
    HOTSPOT_BUILD_JOBS="$HOTSPOT_BUILD_JOBS" \
    PARALLEL_COMPILE_JOBS="$PARALLEL_COMPILE_JOBS" \
    ALLOW_DOWNLOADS=false
} 2>&1 | tee "$repo/work/logs/windows-build.log"

cd "$repo"
image="$(find work/openjdk/build -type d -name j2sdk-image -print -quit)"
[[ -n "$image" && -f "$image/bin/java.exe" && -f "$image/jre/bin/java.exe" ]] || {
  echo 'ERROR: No completed Windows j2sdk-image; refusing to package.' >&2
  exit 1
}
printf '%s\n' "$(cygpath -w "$repo/$image")" > work/windows-jdk-image.txt
echo "Completed Windows JDK image: $image"
