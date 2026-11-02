# Security tracking

## Policy hardening / certificate distrust (2026-11-02)

| Item | Reference | Patch | Validation | Status |
|---|---|---|---|---|
| Refresh SHA-256 certificate blacklist from 38 to 86 fingerprints (+48) | [OpenJDK 8u pinned source](https://github.com/openjdk/jdk8u/blob/b661ee6ff840d6922aa7424a4d8f24760b21cf26/jdk/src/share/lib/security/blacklisted.certs), [JDK-8395142](https://bugs.openjdk.org/browse/JDK-8395142) | `patches/security/0001-refresh-certificate-blacklist-and-tls-policy.patch` | Offline patch tests + packaged JRE/JDK security smoke test | Patch added; native build pending |
| Block all RC4 and static ECDH cipher suites, not just RC4_40 | [Oracle crypto configuration guidance](https://www.java.com/configure_crypto.html) | Same patch, all 4 `java.security-*` platform profiles | `SecuritySmokeTest.java` verifies loaded constraints | Patch added; native build pending |
| Retain existing SSLv3/TLSv1/TLSv1.1, 3DES, DES, NULL and anonymous-suite restrictions | [Java SE 7 JSSE documentation](https://docs.oracle.com/javase/7/docs/technotes/guides/security/jsse/JSSERefGuide.html) | Existing 7u351 policies preserved | Runtime smoke test verifies TLSv1.2 is enabled and obsolete versions are not | Included in policy |

### Source and behavior

- Base source: `openjdk/jdk7u` at `jdk7u351-ga`.
- Certificate blacklist source: `openjdk/jdk8u` commit [`b661ee6ff840d6922aa7424a4d8f24760b21cf26`](https://github.com/openjdk/jdk8u/commit/b661ee6ff840d6922aa7424a4d8f24760b21cf26). This is a pinned **certificate fingerprint list**, not a wholesale Java 8 security implementation backport.
- The Java 7 `sun.security.util.UntrustedCertificates` class already reads `java.home/lib/security/blacklisted.certs` and looks up SHA-256 fingerprints. The patch retains all 38 old entries and adds 48 reviewed upstream entries; the usual Java 7 build places the revised resource in the runtime image.
- `jdk.tls.disabledAlgorithms` already disables TLS 1.0/1.1 in upstream 7u351. This patch only replaces `RC4_40` with `RC4` (all RC4 suites) and adds `ECDH` (static ECDH suites without forward secrecy). The 4 platform profiles are kept consistent.
- We **do not** disable `TLS_RSA_*`, raise minimum DH key length, turn on hard-fail OCSP/CRL checks, or add SHA-1 JAR signing restrictions in this change. Those require compatibility evaluation for legacy games/mods and/or further certificate-validation work.
- No TLS 1.3, OCSP stapling, CRLite, or automatic online revocation checking is added. The current Mozilla `cacerts` import remains independent of the fingerprint blacklist and cannot reflect all Mozilla trust policies.
- The patch is applied **before** compiling Java 7 on Windows and Linux. `tests/test_security_patch.py` checks the bundled patch offline; `tests/SecuritySmokeTest.java` runs against both the staged JRE and JDK to assert installed policies and blacklist entries.
- A handshake with real services, in-game compatibility, and full Linux/Windows CI builds still require validation. Failing an explicit smoke test must fail artifact packaging.

**Not a complete security update.** These changes are configuration/distrust-list hardening, not fixes for CVEs in TLS parsing, PKIX, XML, serialization, JVM internals or native libraries. Do not market generated builds as fully patched or use Java 7 for untrusted production code.
