# Security tracking

| Issue / CVE | Upstream reference | Java 7 patch | Test | Status |
|---|---|---|---|---|
| (none reviewed yet) | — | — | — | Not started |

**Do not market generated builds as fully patched.** Updating a `cacerts`
file does not fix TLS implementation, JVM, serialization, image parsing, XML,
or certificate path validation vulnerabilities.

A change to the trust store affects roots but does not automatically implement
Mozilla's domain-specific trust or distrust policies in Java 7's PKIX engine.
