# Windows x64 / GitHub-hosted Actions (experimental)

`Build legacy OpenJDK 7 (Windows x64 experiment)` is a **separate manual
workflow**, so the original Linux builder is not modified or disabled.

## Run

1. Push this repository folder to GitHub.
2. Actions → **Build legacy OpenJDK 7 (Windows x64 experiment)** → Run workflow.
3. Inspect `windows-x64`. If all native build steps succeed, download the
   `legacy-openjdk7u351-windows-x64` artifact containing two ZIPs and SHA256
   checksums. Otherwise, download `windows-x64-diagnostics` and use the first
   native toolchain error to guide a patch.

## What the workflow does

- Downloads OpenJDK 7u351 from `openjdk/jdk7u`.
- Applies repository patch files under `patches/build/` and `patches/security/`.
- Downloads Azul Zulu JDK **6** (Windows x64 ZIP) strictly as the compiler
  bootstrap. This Java 6 build is never shipped with the output.
- Installs Cygwin, GNU Make and older **Ant 1.9.16**, which can run on JDK 6.
- Downloads Microsoft's Windows SDK 7.1 x64 ISO, verifies its published SHA-1,
  and attempts unattended installation. Uses its MSVC 2010 x64 compiler,
  verifies its version, and fails rather than falling back to VS2022.
- Only if a complete `j2sdk-image` exists, runs `SmokeTest.java`, updates JKS
  `cacerts` using the resulting Java 7 `keytool`, and packages JRE/JDK ZIPs.

## Windows SDK 7.1 limitations

The linked Microsoft download is Windows SDK 7.1, not the Visual Studio IDE;
its x64 ISO includes the VS2010-generation compiler. The SDK does not list
Windows Server 2022 as supported, and its installer can fail silently or omit
components. The workflow checks for SetEnv.cmd and compiler version 16.00;
a successful installation or build on hosted runners is not yet verified.
Microsoft's published SHA-1 identifies this historical ISO but is not a modern
security-strength integrity check. Review Microsoft's SDK license before use.

The build may also require an older DirectX SDK, GNU make, or MSVC runtime.
If the build fails, add only reviewed, legally distributable changes under
`patches/build/`.

The job is deliberately **workflow_dispatch-only** until a complete Windows
build has been produced and tested; this avoids repeatedly failing every push.
The existing Linux tag release job still only publishes Linux binaries.

## Key references

- https://www.microsoft.com/en-us/download/details.aspx?id=8442
- https://learn.microsoft.com/en-us/troubleshoot/developer/visualstudio/installation/install-windows-sdk-silent-mode
- https://github.com/openjdk/jdk7u/blob/jdk7u351-ga/README-builds.html
- https://github.com/actions/runner-images/blob/main/images/windows/Windows2022-Readme.md
- https://cdn.azul.com/zulu/bin/
- https://www.cygwin.com/install.html
- https://archive.apache.org/dist/ant/binaries/

**Security:** This is not a fully patched Java 7. Keep it away from untrusted
code and public services; use a sandboxed legacy game environment.
