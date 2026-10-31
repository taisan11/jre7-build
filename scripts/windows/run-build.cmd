@echo off
setlocal
REM Invoke from repository root on a GitHub-hosted Windows runner.
if not defined VCVARSALL (
  echo ERROR: VCVARSALL not provided by setup-toolchain.ps1 1>&2
  exit /b 2
)
if not defined CYGWIN_ROOT (
  echo ERROR: CYGWIN_ROOT not provided by setup-toolchain.ps1 1>&2
  exit /b 2
)
if not defined BOOT_JDK_DIR (
  echo ERROR: BOOT_JDK_DIR not provided by setup-toolchain.ps1 1>&2
  exit /b 2
)
call "%VCVARSALL%" x64
if errorlevel 1 exit /b %ERRORLEVEL%
set "PATH=%CYGWIN_ROOT%\bin;%PATH%"
"%CYGWIN_ROOT%\bin\bash.exe" --noprofile --norc scripts/windows/build-jdk.sh
exit /b %ERRORLEVEL%
