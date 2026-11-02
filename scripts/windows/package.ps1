# Native Windows ZIP packaging, using the Java 7 keytool to produce a Java 7 JKS.
[CmdletBinding()]
param(
    [string] $UpstreamRef = 'jdk7u351-ga'
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$work = Join-Path $root 'work'
$out = Join-Path $root 'out'
$imagePathFile = Join-Path $work 'windows-jdk-image.txt'
if (-not (Test-Path $imagePathFile)) { throw 'JDK image location not found; build did not complete' }
$jdk = (Get-Content $imagePathFile -Raw).Trim()
foreach ($required in @('bin\java.exe', 'bin\javac.exe', 'bin\keytool.exe', 'jre\bin\java.exe', 'jre\lib\security\cacerts')) {
    if (-not (Test-Path (Join-Path $jdk $required))) { throw "Incomplete JDK: $required" }
}
$stage = Join-Path $out 'stage-windows'
if (Test-Path $stage) { Remove-Item $stage -Recurse -Force }
New-Item -ItemType Directory -Force $stage | Out-Null
$base = 'legacy-openjdk7u351-windows-x64'
$bundle = Join-Path $work 'cacert.pem'
if (-not (Test-Path $bundle)) { throw 'CA bundle not downloaded' }
$sha = (Get-FileHash -Path $bundle -Algorithm SHA256).Hash.ToLowerInvariant()
$upstreamCommit = (Get-Content (Join-Path $work 'upstream-commit.txt') -Raw).Trim()
$patchLog = (Join-Path $work 'applied-patches.txt')
$patches = if (Test-Path $patchLog) { @(Get-Content $patchLog) } else { @() }
$securitySmokeDir = Join-Path $work 'security-smoke-classes'
New-Item -ItemType Directory -Force $securitySmokeDir | Out-Null
& (Join-Path $jdk 'bin\javac.exe') -source 7 -target 7 -d $securitySmokeDir (Join-Path $root 'tests\SecuritySmokeTest.java')
if ($LASTEXITCODE -ne 0) { throw 'Security smoke test compilation failed' }

foreach ($kind in @('jre', 'jdk')) {
    $name = "$base-$kind"
    $dest = Join-Path $stage $name
    New-Item -ItemType Directory -Force $dest | Out-Null
    $from = if ($kind -eq 'jre') { Join-Path $jdk 'jre' } else { $jdk }
    Copy-Item (Join-Path $from '*') -Destination $dest -Recurse -Force
    $keystore = if ($kind -eq 'jre') {
        Join-Path $dest 'lib\security\cacerts'
    } else {
        Join-Path $dest 'jre\lib\security\cacerts'
    }
    & python (Join-Path $root 'scripts\cacerts.py') --bundle $bundle --keytool (Join-Path $jdk 'bin\keytool.exe') --keystore $keystore --metadata (Join-Path $dest 'CA-METADATA.json')
    if ($LASTEXITCODE -ne 0) { throw "CA import failed: $kind" }
    & (Join-Path $dest 'bin\java.exe') -version
    if ($LASTEXITCODE -ne 0) { throw "Java 7 launch failed: $kind" }
    & (Join-Path $dest 'bin\java.exe') -cp $securitySmokeDir SecuritySmokeTest
    if ($LASTEXITCODE -ne 0) { throw "Java 7 security smoke test failed: $kind" }
    $license = Join-Path $root 'work\openjdk\LICENSE'
    if (Test-Path $license) { Copy-Item $license (Join-Path $dest 'OPENJDK-SOURCE-LICENSE.txt') }
    $thirdParty = Join-Path $root 'work\openjdk\THIRD_PARTY_README'
    if (Test-Path $thirdParty) { Copy-Item $thirdParty (Join-Path $dest 'OPENJDK-THIRD-PARTY-README.txt') }
    $metadata = [ordered]@{
        upstream = 'https://github.com/openjdk/jdk7u'
        upstream_ref = $UpstreamRef
        upstream_commit = $upstreamCommit
        builder_commit = $env:GITHUB_SHA
        run_id = $env:GITHUB_RUN_ID
        ca_source = 'https://curl.se/ca/cacert.pem'
        ca_bundle_sha256 = $sha
        applied_patches = $patches
        security_status = 'EXPERIMENTAL; NOT FULLY SECURITY PATCHED'
    }
    $metadata | ConvertTo-Json -Depth 5 | Set-Content -Path (Join-Path $dest 'BUILD-METADATA.json') -Encoding utf8
    $archive = Join-Path $out "$name.zip"
    if (Test-Path $archive) { Remove-Item $archive -Force }
    Compress-Archive -Path $dest -DestinationPath $archive -CompressionLevel Optimal
    $digest = (Get-FileHash -Path $archive -Algorithm SHA256).Hash.ToLowerInvariant()
    "$digest  $name.zip" | Set-Content -Path "$archive.sha256" -Encoding ascii
    Write-Host "Created $archive ($digest)"
}
