# Windows x64 full release build

Windows is built together with Linux by the **Full Release Build (OpenJDK
7u351)** workflow. There is no separate experimental Windows action. The
workflow always attempts a complete native JRE/JDK build on a Windows 2022
runner using Windows SDK 7.1 (VS2010-generation MSVC), not VS2022.

## Run

Actions → **Full Release Build (OpenJDK 7u351)** → Run workflow.

The only inputs are **Publish to the GitHub Releases tab** (checkbox)
and **Release tag** (required if the box is checked). Both platforms
must pass before a Release is created. Otherwise, successful builds are
available in the workflow's Artifacts section.

## Windows build and cache

1. Fetch pinned OpenJDK 7u351 and apply the reviewed security/build patches.
2. Restore the complete Windows x64 compiled JDK image if its cache key
   matches the current patches and all Windows build scripts.
3. On a cache miss, restore downloaded toolchain archives and install Azul
   Zulu JDK 6 (bootstrap only), Ant 1.9.16, Cygwin, Microsoft's Windows SDK
   7.1, DirectX June 2010 SDK files, legacy CMake and FreeType sources.
4. Compile FreeType with MSVC 2010 and build the **full** Java 7 JDK image.
   Save only the completed image after Java smoke/security tests and packaging.
5. On both cache hits and misses, download fresh Mozilla root certificates,
   create Java 7-compatible JKS stores, run the runtime/security smoke tests,
   and package Windows x64 JRE/JDK ZIPs and SHA-256 checksums.

The Windows compiler installation is not persisted in the GitHub Actions
cache, because Windows runner system installations must be recreated. The
download cache avoids repeated large downloads after a compiled-image miss.
Both the legacy Windows SDK ISO and DirectX SDK downloads are checked against
pinned digests; cached inputs are not exempt from those checks.

## Limitations

Windows SDK 7.1 on a Windows Server 2022 GitHub runner is unsupported by
Microsoft, despite earlier successful native CI runs. A cache miss still
depends on old installers, mirrors and compiler behavior. Build failures
upload `windows-x64-diagnostics` with logs. Existing compiled-image caches
cannot be used after relevant build scripts or patches change.

Legacy Java 7 is **not fully security-patched**, and refreshing the CA
certificates does not make it appropriate for untrusted code or production
services. See [security tracking](SECURITY-TRACKING.md).

## References

- https://www.microsoft.com/en-us/download/details.aspx?id=8442
- https://learn.microsoft.com/en-us/troubleshoot/developer/visualstudio/installation/install-windows-sdk-silent-mode
- https://github.com/openjdk/jdk7u/blob/jdk7u351-ga/README-builds.html
- https://github.com/actions/cache
