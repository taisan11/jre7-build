"""Offline checks for the pinned Java 7 security policy backport."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]
PATCH = ROOT / "patches" / "security" / "0001-refresh-certificate-blacklist-and-tls-policy.patch"
PROFILES = ("linux", "windows", "macosx", "solaris")


def file_diff(path):
    text = PATCH.read_text(encoding="utf-8")
    marker = "diff --git a/" + path + " b/" + path + "\n"
    assert text.count(marker) == 1, path
    return text.split(marker, 1)[1].split("diff --git a/", 1)[0]


class SecurityPatchTests(unittest.TestCase):
    def test_blacklist_is_sha256_and_preserves_base(self):
        section = file_diff("jdk/src/share/lib/security/blacklisted.certs")
        additions = [line[1:] for line in section.splitlines()
                     if line.startswith("+") and not line.startswith("+++")]
        removals = [line[1:] for line in section.splitlines()
                    if line.startswith("-") and not line.startswith("---")]
        self.assertEqual(additions[0], "Algorithm=SHA-256")
        self.assertEqual(removals[0], "Algorithm=SHA-256")
        self.assertEqual(len(additions) - 1, 86)
        self.assertEqual(len(removals) - 1, 38)
        self.assertEqual(len(set(additions)), len(additions))
        self.assertEqual(additions[1:], sorted(additions[1:]))
        self.assertTrue(set(removals[1:]).issubset(set(additions[1:])))
        for digest in additions[1:]:
            self.assertRegex(digest, r"^[A-F0-9]{64}$")

    def test_tls_policy_on_every_upstream_platform(self):
        for platform in PROFILES:
            with self.subTest(platform=platform):
                section = file_diff("jdk/src/share/lib/security/java.security-" + platform)
                added = " ".join(line[1:].rstrip(" \\")
                                 for line in section.splitlines()
                                 if line.startswith("+") and not line.startswith("+++"))
                self.assertIn("jdk.tls.disabledAlgorithms=", added)
                for token in ("SSLv3", "TLSv1", "TLSv1.1", "RC4",
                              "ECDH", "3DES_EDE_CBC", "anon", "NULL",
                              "include jdk.disabled.namedCurves"):
                    self.assertIn(token, added)
                self.assertNotIn("RC4_40", added)


if __name__ == "__main__":
    unittest.main()
