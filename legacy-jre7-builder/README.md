# Legacy OpenJDK 7 builder (experimental)

Build **OpenJDK 7u351** from publicly available source on GitHub Actions and
package legacy-game-friendly **Linux x86_64 JRE and JDK ZIPs**, with a separate **experimental Windows x64 build workflow**, and an updated
Mozilla root CA bundle.

> **Important:** This is an unverified CI build template, not a completed or
> supported Java 7 distribution. Its GitHub Actions build has not been run.
> Updating the CA store does **not** fix Java 7 security vulnerabilities.
> No security backports are bundled yet. Do not treat artifacts as suitable
> for untrusted code or security-sensitive production applications.

## Quick start

1. Create an empty GitHub repository (default branch `main`).
2. Copy/push the contents of this folder to the repository.
3. For Linux, open **Actions → Build legacy OpenJDK 7 → Run workflow**.
   For Windows x64, open **Actions → Build legacy OpenJDK 7 (Windows x64 experiment) → Run workflow** (see [Windows build guide](docs/WINDOWS-X64.md)).
4. After a successful run, download the `legacy-openjdk7u351-linux-x64`
   artifact (contains the JRE/JDK ZIPs and SHA-256 checksums).
5. Optionally push a `v0.1.0` tag to publish the archives under **Releases**.

**The Linux workflow is unchanged.** The new Windows x64 job is manual and experimental:
upstream Java 7 expects VS2010 whereas the GitHub-hosted runner has VS2022.
Windows compilation is **not verified and is likely to fail without substantial
source compatibility patches**. Failed jobs upload diagnostics rather than
pretending to create Windows binaries.

## File layout

```text
.github/workflows/build.yml  Existing Linux build, test, artifact, release
.github/workflows/build-windows.yml  Windows-hosted experimental native build
Dockerfile (under docker/) Ubuntu 14.04 build toolchain
scripts/fetch-source.sh    Clone pinned source ref
scripts/apply-patches.sh   Apply reviewed patch files before building
docker/build-jdk.sh        Native OpenJDK build in isolated container
scripts/cacerts.py         Convert curl/Mozilla PEM bundle into Java 7 JKS
scripts/package.sh         Assemble Linux JRE/JDK and create ZIP files
scripts/windows/           Cygwin/toolchain setup, Windows build and packaging
docs/WINDOWS-X64.md        Windows-specific limitations and instructions
patches/security/          Reviewed security backports (empty initially)
patches/build/             Toolchain compatibility patches (empty initially)
docs/SECURITY-TRACKING.md  Backport tracking checklist
tests/                     Unit tests and Java 7 runtime smoke test
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

To add an audited backport, place a `*.patch` under `patches/security/` and
update `docs/SECURITY-TRACKING.md`. Patches are applied in lexicographic order
before compilation. This template deliberately includes no claimed CVE fixes.

## Failure modes / current limitations

- The pre-2015 build environment is end-of-life. Old archive mirrors can become
  unavailable, and `ubuntu:14.04` can stop being published.
- Upstream build rules / newer host kernels can require additional patches.
- GitHub-hosted Actions resources may be insufficient for some native builds.
- Linux x86_64 remains the only *previously configured* native target. An experimental Windows x64 workflow has been added; macOS and 32-bit builds are not configured.
- The ZIPs and `cacerts` processing were **not** exercised against a real
  completed 7u351 build in this environment; a CI run is required to validate.
- No reproducibility or binary signatures are guaranteed; consider pinning the
  container digest and CA bundle revision when moving beyond experiments.
