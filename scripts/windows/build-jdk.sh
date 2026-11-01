#!/usr/bin/env bash
# Run under Cygwin, with vcvarsall.bat already called by run-build.cmd.
set -euo pipefail

repo="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$repo"
mkdir -p work/logs out

: "${BOOT_JDK_DIR:?Windows JDK6 bootstrap home required}"
: "${LEGACY_ANT_HOME:?Windows Ant 1.9 home required}"
: "${SDK_SETENV:?Windows SDK 7.1 environment required}"

# MSVC's PATH/INCLUDE/LIB come from SDK 7.1 SetEnv.cmd (Windows cmd parent).
# Windows paths exported here are converted for Cygwin build tools.
boot_dir="$(cygpath -m "$BOOT_JDK_DIR")"
export ALT_BOOTDIR="$boot_dir"
export ALT_JDK_IMPORT_PATH="$boot_dir"
export ANT_HOME="$(cygpath -m "$LEGACY_ANT_HOME")"
# SetEnv.cmd can change the Windows environment variable's capitalization.
# Cygwin and GNU make treat it case-sensitively, so export the exact spelling
# expected by OpenJDK, using a space-free path for make recipes.
sdk_dir="$(dirname "$(dirname "$(cygpath -u "$SDK_SETENV")")")"
export WINDOWSSDKDIR="$(cygpath -m -s "$sdk_dir")"
[[ -f "$sdk_dir/Bin/SetEnv.cmd" && "$WINDOWSSDKDIR" != *' '* ]] || {
  echo 'Windows SDK 7.1 directory is missing or lacks an 8.3 short path' >&2
  exit 1
}
# A separate DirectX June 2010 SDK is extracted without installing its
# incompatible redistributables. Keep paths space-free for legacy GNU make.
: "$DXSDK_ROOT"
: "$FT_INSTALL"
dx_root="$(cygpath -u "$DXSDK_ROOT")"
ft_root="$(cygpath -u "$FT_INSTALL")"
export ALT_DXSDK_PATH="$(cygpath -m "$dx_root")"
export ALT_DXSDK_INCLUDE_PATH="$(cygpath -m "$dx_root/Include")"
export ALT_DXSDK_LIB_PATH="$(cygpath -m "$dx_root/Lib/x64")"
export ALT_FREETYPE_HEADERS_PATH="$(cygpath -m "$ft_root/include/freetype2")"
export ALT_FREETYPE_LIB_PATH="$(cygpath -m "$ft_root/lib")"
for required in "$dx_root/Include/d3d9.h" "$dx_root/Include/d3dx9.h" \
                "$dx_root/Lib/x64/d3d9.lib" "$dx_root/Lib/x64/d3dx9.lib" \
                "$ft_root/include/freetype2/ft2build.h" \
                "$ft_root/lib/freetype.lib" "$ft_root/lib/freetype.dll"; do
  [[ -f "$required" ]] || { echo "Required native dependency missing: $required" >&2; exit 1; }
done
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

# SDK 7.1 includes the VS2010 compiler but not VS100COMNTOOLS from the full
# IDE. Bypass that IDE discovery and point make at the SDK's actual tools.
compiler_exe="$(command -v cl.exe)"
resource_exe="$(command -v rc.exe)"
export ALT_COMPILER_PATH="$(cygpath -m -s "$(dirname "$compiler_exe")")"
export ALT_MSDEVTOOLS_PATH="$(cygpath -m -s "$(dirname "$resource_exe")")"
[[ "$ALT_COMPILER_PATH" != *' '* && "$ALT_MSDEVTOOLS_PATH" != *' '* ]] || {
  echo 'MSVC or Windows SDK path has spaces and no usable 8.3 short name' >&2
  exit 1
}
export VS2010_EXISTS=true

set -o pipefail
{
  echo '== Windows Java 7 native build: EXPERIMENTAL =='
  echo 'Host: GitHub-hosted windows-2022 with Windows SDK 7.1 / MSVC 2010'
  echo 'Warning: SDK 7.1 on Windows Server 2022 is unsupported and experimental.'
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
  echo "SDK-only VS2010 discovery override; SDK: $WINDOWSSDKDIR; compiler: $ALT_COMPILER_PATH; SDK tools: $ALT_MSDEVTOOLS_PATH"
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
