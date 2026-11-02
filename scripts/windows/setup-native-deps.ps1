# Fetch Windows-native dependencies without installing the legacy DirectX SDK.
# The June 2010 SDK conflicts with newer VC++ redistributables when installed.
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$work = Join-Path $root 'work'
$downloads = Join-Path $work 'native-downloads'
New-Item -ItemType Directory -Force -Path $downloads | Out-Null

function Download-Checked([string] $Url, [string] $Path, [int64] $MinBytes) {
    if ((Test-Path $Path) -and (Get-Item $Path).Length -ge $MinBytes) {
        Write-Host "Reusing cached native dependency: $Path"
    } else {
        Write-Host "Downloading $Url"
        Invoke-WebRequest -Uri $Url -OutFile $Path -MaximumRedirection 5
    }
    if (-not (Test-Path $Path) -or (Get-Item $Path).Length -lt $MinBytes) {
        throw "Native dependency download was missing/truncated: $Url"
    }
    Write-Host "SHA-256 $( (Get-FileHash -Path $Path -Algorithm SHA256).Hash ): $Path"
}

# Microsoft's official DXSDK_Jun10.exe. Extract SDK files only, never run the
# deprecated redistributable installers on the hosted CI image.
$dxExe = Join-Path $downloads 'DXSDK_Jun10.exe'
Download-Checked 'https://download.microsoft.com/download/A/E/7/AE743F1F-632B-4809-87A9-AA1BB3458E31/DXSDK_Jun10.exe' $dxExe 500MB
$dxHash = (Get-FileHash -Path $dxExe -Algorithm SHA256).Hash.ToUpperInvariant()
# Pinned digest published by the Chocolatey DirectX SDK package for this URL.
if ($dxHash -ne '705271DC83BFEE54D9B94E028426E288D5F070784B7446D164F48ECFBB2A02CB') {
    throw "DirectX SDK digest changed: $dxHash. Review before updating the pin."
}
$sevenZip = (Get-Command '7z.exe' -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty Source)
if (-not $sevenZip) { $sevenZip = 'C:\Program Files\7-Zip\7z.exe' }
if (-not (Test-Path $sevenZip)) { throw '7-Zip unavailable on Windows runner' }
$dxExtract = Join-Path $work 'dxsdk-extracted'
New-Item -ItemType Directory -Force -Path $dxExtract | Out-Null
& $sevenZip x '-y' "-o$dxExtract" $dxExe 'DXSDK/Include/*' 'DXSDK/Lib/x64/*'
if ($LASTEXITCODE -ne 0) { throw 'DirectX SDK extraction failed' }
$dxRoot = Join-Path $dxExtract 'DXSDK'
foreach ($file in @('Include\d3d9.h', 'Include\d3dx9.h', 'Lib\x64\d3d9.lib', 'Lib\x64\d3dx9.lib')) {
    if (-not (Test-Path (Join-Path $dxRoot $file))) { throw "Missing DirectX SDK file: $file" }
}
"DXSDK_ROOT=$dxRoot" | Out-File -FilePath $env:GITHUB_ENV -Encoding utf8 -Append

# FreeType 2.10.4 still supports the VS2010 compiler, whereas the current
# Cygwin FreeType binary cannot be linked into a native MSVC-built JDK.
$ftZip = Join-Path $downloads 'freetype-2.10.4.zip'
Download-Checked 'https://github.com/freetype/freetype/archive/refs/tags/VER-2-10-4.zip' $ftZip 1MB
$ftExtract = Join-Path $work 'freetype-source'
Expand-Archive -Path $ftZip -DestinationPath $ftExtract -Force
$ftSource = Get-ChildItem $ftExtract -Directory |
    Where-Object { Test-Path (Join-Path $_.FullName 'CMakeLists.txt') } |
    Select-Object -First 1 -ExpandProperty FullName
if (-not $ftSource) { throw 'FreeType source extraction failed' }
"FT_SOURCE=$ftSource" | Out-File -FilePath $env:GITHUB_ENV -Encoding utf8 -Append
"FT_INSTALL=$(Join-Path $work 'freetype-install')" | Out-File -FilePath $env:GITHUB_ENV -Encoding utf8 -Append

# Newer CMake releases may no longer recognize MSVC 2010. Use a known legacy
# CMake that supports both NMake Makefiles and the SDK 7.1 compiler.
$cmakeZip = Join-Path $downloads 'cmake-3.20.6.zip'
Download-Checked 'https://github.com/Kitware/CMake/releases/download/v3.20.6/cmake-3.20.6-windows-x86_64.zip' $cmakeZip 10MB
$cmakeExtract = Join-Path $work 'legacy-cmake'
Expand-Archive -Path $cmakeZip -DestinationPath $cmakeExtract -Force
$cmake = Get-ChildItem $cmakeExtract -Filter 'cmake.exe' -Recurse -File |
    Select-Object -First 1 -ExpandProperty FullName
if (-not $cmake) { throw 'Legacy CMake binary not found' }
"CMAKE_EXE=$cmake" | Out-File -FilePath $env:GITHUB_ENV -Encoding utf8 -Append
& $cmake --version
if ($LASTEXITCODE -ne 0) { throw 'Legacy CMake failed to start' }
Write-Host "DirectX SDK: $dxRoot"
Write-Host "FreeType source: $ftSource"
