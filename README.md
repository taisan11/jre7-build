# OpenJDK 7 Build

GitHub Actionsを用いて`OpenJDK 7u351`をビルドして提供しています。
最新のMozilla提供の証明書を反映し、一部のSecurityパッチを適用しています。
Linux x86_64・Windows x64向けのフルJRE/JDK ZIPを生成します。

> **Security:** This project is an experimental community build of legacy
> Java 7, not a fully security-patched or vendor-supported runtime. The
> certificate blacklist / TLS policy changes do not backport all CVE fixes.
> Do not use it to run untrusted code or security-sensitive services.

## Run a full release build

Open **Actions → Full Release Build (OpenJDK 7u351) → Run workflow**.
There are exactly two optional publication controls:

- **Publish to the GitHub Releases tab**: checkbox, off by default.
- **Release tag**: text field, needed only when the checkbox is enabled
  (for example `v7u351-20261102`). The workflow validates the tag first.

Every run builds and smoke-tests **both OS targets and both JRE/JDK packages**.
The four ZIP archives and their SHA-256 files are always available as Actions
artifacts for 30 days. When publishing is enabled, the workflow **waits for
both jobs to succeed**, verifies all four checksums, and creates a GitHub
Release using the supplied tag at the commit that was built. It refuses to
overwrite an existing release or to reuse a tag pointing elsewhere.

A full build is never published when only one platform succeeds. Release
publishing is not triggered automatically by a tag push.

## Build acceleration / cache

- Each platform caches only the **completed JDK release image**. A hit skips
  the old toolchain installation and native compilation, but source/patch
  checkout, fresh CA download, runtime/security tests, packaging and checksum
  generation still run.
- Keys are separated by OS and derived from the pinned upstream version,
  build scripts and patches. Changing any build input invalidates the compiled
  image. Tests and downloaded roots do not unnecessarily invalidate it.
- Linux also reuses its Buildx GitHub Actions cache for the old Ubuntu 14.04
  toolchain Docker image on a compiled-image miss.
- Windows caches downloads of the legacy Windows SDK 7.1, DirectX SDK, JDK 6
  bootstrap, Ant, CMake, FreeType and Cygwin packages on a compiled-image
  miss. SDK and DirectX downloads are checked against their pinned digests.
- GitHub caches are scoped to branches, subject to the GitHub Actions cache
  retention / storage limits. A cache miss always performs a **full native
  release build**, not an incremental or reduced build.

## File layout

```text
.github/workflows/build.yml  Only Actions workflow; full Linux/Windows build and optional release
docker/                       Ubuntu 14.04 legacy Linux build toolchain
scripts/fetch-source.sh       Clone pinned source ref
scripts/apply-patches.sh      Apply audited patches before building
docker/build-jdk.sh           Linux native JDK compilation and smoke test
scripts/cacerts.py            Generate compatible Java 7 JKS from Mozilla PEM
scripts/package.sh            Linux JRE/JDK packaging and SHA-256
scripts/windows/              Windows setup, native build and packaging
docs/WINDOWS-X64.md           Windows compiler details and limitations
patches/security/             Certificate blacklist and TLS policy patches
patches/build/                Toolchain compatibility patches
docs/SECURITY-TRACKING.md     Security backport tracking
tests/                       Python and Java smoke tests
```

## Source and toolchain

- OpenJDK: https://github.com/openjdk/jdk7u, `jdk7u351-ga` (source fetched at CI runtime).
- Bootstrap: Ubuntu 14.04 `openjdk-6-jdk` (Java 6).
- Compiler: GCC/G++ 4.8, GNU make, Ant; OS packages from Ubuntu's EOL archives.
- Root bundle: https://curl.se/ca/cacert.pem (derived from Mozilla's root CA
  program and downloaded freshly for every run).
- Build metadata includes source commit, SHA-256 of CA bundle, and backports.

OpenJDK source and the resulting Java runtime are governed by GPLv2 and
associated Classpath/assembly exceptions, not by this repository's script
license. Consult the upstream license headers and bundle corresponding
source/patches when redistributing binaries.

This builder borrows the **build / certificate-generation approach** from the
Adoptium/Temurin ecosystem; this is **not an Eclipse Temurin build** or
associated with Eclipse Adoptium. Temurin does not release Java 7.

## Legacy Minecraft goals

- Preserve the Java 7 class library, JNI, AWT/Swing, sound, and HotSpot.
- Avoid removing old runtime APIs used by older game launchers and LWJGL 2.
- The Java smoke test checks the language runtime, SSLContext and AWT class
  availability, **not** actual Minecraft 1.2.5 / LWJGL 2 / OpenGL rendering.
- ZIPs contain native Linux `.so` binaries. Test against intended game/mod packs
  before claiming compatibility.

## Certificates and security

`cacerts.py` imports X.509 roots from the current `curl.se` Mozilla PEM bundle
into a **new JKS** using the freshly built Java 7 `keytool`, instead of copying
Java 8/17 PKCS12 files. It validates uniqueness and aborts if there are fewer
than 50 roots. Metadata is stored inside each archive as `CA-METADATA.json`.

**Limitations:** Java 7 cannot automatically reproduce all contemporary
Mozilla trust restrictions, its own algorithm constraints may differ, and
updating root CAs does not remove vulnerable crypto protocol implementations.
Test HTTPS with the target games; do not disable certificate verification to
work around errors.

A pinned certificate blacklist refresh and TLS policy hardening are applied during compilation on Linux and Windows (see [security tracking](docs/SECURITY-TRACKING.md)). To add another audited backport, place a `*.patch` under `patches/security/` and
update `docs/SECURITY-TRACKING.md`. Patches are applied in lexicographic order
before compilation. The bundled configuration patch is not a CVE implementation backport and does not make Java 7 safe for untrusted workloads.

## Failure modes / current limitations

- The pre-2015 build environment is end-of-life. Old archive mirrors can become
  unavailable, and `ubuntu:14.04` can stop being published.
- Upstream build rules / newer host kernels can require additional patches.
- GitHub-hosted Actions resources may be insufficient for some native builds.
- Linux x86_64 and Windows x64 are configured as full native build targets. macOS and 32-bit builds are not configured.
- A successful Windows native workflow run exists, but Linux and both release archives must still be validated by the combined workflow before distribution.
- No reproducibility or binary signatures are guaranteed; consider pinning the
  container digest and CA bundle revision when moving beyond experiments.
