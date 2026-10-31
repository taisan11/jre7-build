@echo off
setlocal
REM Invoke from repository root on a GitHub-hosted Windows runner.
if not defined SDK_SETENV (
  echo ERROR: SDK_SETENV not provided by setup-toolchain.ps1 1>&2
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
REM Remove pre-existing developer environment so SDK 7.1 cannot fall back to VS2022.
set "VCINSTALLDIR="
set "VSINSTALLDIR="
set "VSLANG=1033"
call "%SDK_SETENV%" /x64 /release
if errorlevel 1 exit /b %ERRORLEVEL%
cl.exe 2>&1 | findstr /R /C:"Version 16\.00\." >nul
if errorlevel 1 (
  echo ERROR: Windows SDK did not select the VS2010 16.00 compiler. 1>&2
  where cl.exe
  exit /b 2
)
set "PATH=%CYGWIN_ROOT%\bin;%PATH%"
"%CYGWIN_ROOT%\bin\bash.exe" --noprofile --norc scripts/windows/build-jdk.sh
exit /b %ERRORLEVEL%
