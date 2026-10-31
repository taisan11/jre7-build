import hashlib
import importlib.util
from pathlib import Path
import ssl
import tempfile
import unittest

MODULE = Path(__file__).resolve().parents[1] / 'scripts' / 'cacerts.py'
spec = importlib.util.spec_from_file_location('cacerts', MODULE)
cacerts = importlib.util.module_from_spec(spec)
spec.loader.exec_module(cacerts)

# A syntactically valid PEM cert example: use a repository-independent system
# certificate if available for the local test, never depend on the network.
class CertBundleTests(unittest.TestCase):
    def test_missing_certs_fail(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / 'bundle.pem'
            path.write_text('not a certificate')
            with self.assertRaises(ValueError):
                cacerts.parse_pem_bundle(path)

    def test_non_ascii_comments_are_ignored(self):
        pem = b'-----BEGIN CERTIFICATE-----\nAQID\n-----END CERTIFICATE-----'
        bundle = b'Certificate name: \xc5\x81\n' + pem + b'\n'
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / 'bundle.pem'
            path.write_bytes(bundle)
            certs, fingerprints, digest = cacerts.parse_pem_bundle(path)
        self.assertEqual(certs, [pem.decode('ascii')])
        self.assertEqual(fingerprints, [hashlib.sha256(b'\x01\x02\x03').hexdigest()])
        self.assertEqual(digest, hashlib.sha256(bundle).hexdigest())

    def test_non_ascii_in_certificate_is_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / 'bundle.pem'
            path.write_bytes(b'-----BEGIN CERTIFICATE-----\n\xc5\n-----END CERTIFICATE-----')
            with self.assertRaises(UnicodeDecodeError):
                cacerts.parse_pem_bundle(path)

    def test_bundle_dedup_detected(self):
        bundle = Path('/etc/ssl/certs/ca-certificates.crt')
        if not bundle.exists():
            self.skipTest('No OS CA bundle available')
        certs, fingerprints, digest = cacerts.parse_pem_bundle(bundle)
        self.assertGreaterEqual(len(certs), 50)
        self.assertEqual(len(digest), 64)
        self.assertEqual(len(certs), len(fingerprints))
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / 'dup.pem'
            path.write_text(certs[0] + '\n' + certs[0] + '\n')
            with self.assertRaisesRegex(ValueError, 'Duplicate'):
                cacerts.parse_pem_bundle(path)


if __name__ == '__main__':
    unittest.main()
