# Install the *available* part of the Java 7 Windows toolchain on a GitHub-hosted
# windows-2022 runner. This DOES NOT turn MSVC 2022 into MSVC 2010.
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$work = Join-Path $root 'work'
New-Item -ItemType Directory -Force -Path $work, (Join-Path $work 'logs') | Out-Null

function Download-File([string] $Url, [string] $Path) {
    Write-Host "Downloading $Url"
    Invoke-WebRequest -Uri $Url -OutFile $Path -MaximumRedirection 5
    if (-not (Test-Path $Path) -or (Get-Item $Path).Length -lt 1000) {
        throw "Download failed or too small: $Url"
    }
    $sha = (Get-FileHash -Algorithm SHA256 -Path $Path).Hash
    Write-Host "SHA-256: $sha ($Path)"
}

# Public, older Zulu 6 Community Archive: BOOTSTRAP ONLY, never distributed.
# No Java 7 artifact is copied from Azul; the built OpenJDK is compiled from source.
$zuluFile = 'zulu6.22.0.3-ca-jdk6.0.119-win_x64.zip'
$zuluZip = Join-Path $work $zuluFile
Download-File "https://cdn.azul.com/zulu/bin/$zuluFile" $zuluZip
$bootstrap = Join-Path $work 'bootstrap'
New-Item -ItemType Directory -Force $bootstrap | Out-Null
Expand-Archive -Path $zuluZip -DestinationPath $bootstrap -Force
$javac = Get-ChildItem -Path $bootstrap -Filter javac.exe -File -Recurse | Select-Object -First 1
if (-not $javac) { throw 'Java 6 bootstrap compiler not found in Azul ZIP' }
$bootDir = $javac.Directory.Parent.FullName
& (Join-Path $bootDir 'bin\java.exe') -version
if ($LASTEXITCODE -ne 0) { throw 'Could not run Java 6 bootstrap JVM' }
"BOOT_JDK_DIR=$bootDir" | Out-File -FilePath $env:GITHUB_ENV -Encoding utf8 -Append

# Ant 1.9 is Java-6-compatible; current GitHub runner Ant 1.10 is not.
$antVersion = '1.9.16'
$antZip = Join-Path $work "apache-ant-$antVersion-bin.zip"
Download-File "https://archive.apache.org/dist/ant/binaries/apache-ant-$antVersion-bin.zip" $antZip
$antExtract = Join-Path $work 'ant'
Expand-Archive -Path $antZip -DestinationPath $antExtract -Force
$antHome = Join-Path $antExtract "apache-ant-$antVersion"
if (-not (Test-Path (Join-Path $antHome 'lib\ant-launcher.jar'))) {
    throw 'Ant launcher missing'
}
"LEGACY_ANT_HOME=$antHome" | Out-File -FilePath $env:GITHUB_ENV -Encoding utf8 -Append

# Old JDK makefiles need a POSIX environment and GNU make.
# Cygwin verifies downloaded package metadata by default; DO NOT --no-verify.
$cygRoot = Join-Path $work 'cygwin64'
$cygInstaller = Join-Path $work 'setup-x86_64.exe'
Download-File 'https://cygwin.com/setup-x86_64.exe' $cygInstaller
$cygArgs = @(
    '--quiet-mode', '--wait', '--no-admin', '--no-desktop', '--no-shortcuts',
    '--only-site', '--site', 'https://mirrors.kernel.org/sourceware/cygwin/',
    '--root', $cygRoot, '--local-package-dir', (Join-Path $work 'cygwin-packages'),
    '--packages', 'bash,make,zip,unzip,perl,gawk,sed,grep,findutils,coreutils,which,patch,diffutils,tar'
)
$proc = Start-Process -FilePath $cygInstaller -ArgumentList $cygArgs -Wait -PassThru -NoNewWindow
if ($proc.ExitCode -ne 0) { throw "Cygwin installer exited $($proc.ExitCode)" }
$cygBash = Join-Path $cygRoot 'bin\bash.exe'
if (-not (Test-Path $cygBash)) { throw 'Cygwin bash missing after setup' }
"CYGWIN_ROOT=$cygRoot" | Out-File -FilePath $env:GITHUB_ENV -Encoding utf8 -Append

# Cygwin script for invoking Ant 1.9 with the Java 6 bootstrap, without
# accidentally choosing newer Ant / Java from the host image PATH.
# Keep the wrapper in the workspace, not under a guessed Cygwin mount path.
$localBin = Join-Path $work 'cygwin-tools'
New-Item -ItemType Directory -Force $localBin | Out-Null
$antWrapperPath = Join-Path $localBin 'ant'
$antWrapper = @'
#!/usr/bin/env bash
set -e
bootstrap="$(cygpath -u "$BOOT_JDK_DIR")"
ant_home="$(cygpath -u "$LEGACY_ANT_HOME")"
exec "$bootstrap/bin/java" -cp "$ant_home/lib/ant-launcher.jar" org.apache.tools.ant.launch.Launcher "$@"
'@
[System.IO.File]::WriteAllText($antWrapperPath, ($antWrapper + "`n"), (New-Object System.Text.UTF8Encoding $false))
& $cygBash --noprofile --norc -c 'path=$(cygpath -u "$1") && chmod +x "$path" && test -x "$path"' -- $antWrapperPath
if ($LASTEXITCODE -ne 0) { throw 'Failed to enable Cygwin Ant wrapper' }

# Select installed Visual Studio C++ tools; on hosted runners this is VS2022.
$vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
if (-not (Test-Path $vswhere)) { throw 'vswhere.exe not found' }
$vsRoot = (& $vswhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath | Select-Object -First 1)
if (-not $vsRoot) { throw 'No Visual Studio C++ tools installed' }
$vcvars = Join-Path $vsRoot 'VC\Auxiliary\Build\vcvarsall.bat'
if (-not (Test-Path $vcvars)) { throw "vcvarsall.bat missing: $vcvars" }
"VCVARSALL=$vcvars" | Out-File -FilePath $env:GITHUB_ENV -Encoding utf8 -Append

Write-Warning 'OpenJDK 7 expects VS2010 (v100); GitHub-hosted Windows 2022 has VS2022 (v143). This is an experimental build attempt, not a proven port.'
Write-Host "Bootstrap JDK: $bootDir"
Write-Host "Cygwin: $cygRoot"
Write-Host "Ant 1.9: $antHome"
Write-Host "MSVC: $vcvars"
