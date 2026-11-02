# Java 7 security patches

`0001-refresh-certificate-blacklist-and-tls-policy.patch` is applied by `scripts/apply-patches.sh` against the pinned `openjdk/jdk7u` `jdk7u351-ga` source before compilation.

It merges SHA-256 certificate fingerprints from pinned OpenJDK 8u into Java 7's `blacklisted.certs` and strengthens the four platform `java.security-*` TLS profiles. This is a security policy update, **not** a backport of implementation CVE fixes.

For provenance, compatibility decisions, and validation see [security tracking](../../docs/SECURITY-TRACKING.md). Further security changes must include upstream references, regression tests, and compatibility notes.
