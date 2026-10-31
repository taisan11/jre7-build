#!/usr/bin/env python3
"""Build a Java 7 compatible JKS trust store from a Mozilla PEM bundle.

Input: https://curl.se/ca/cacert.pem (managed by curl.se from Mozilla's list).
Only the PEM certificate blocks are imported. Certificate path constraints,
OneCRL, CRLite, and distrust-after settings are NOT imported.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import ssl
import subprocess
import tempfile

CERT_RE = re.compile(
    rb"-----BEGIN CERTIFICATE-----\s+.*?\s+-----END CERTIFICATE-----",
    re.DOTALL,
)


def parse_pem_bundle(path):
    bundle_bytes = Path(path).read_bytes()
    # Comments and certificate names in the bundle may contain non-ASCII text.
    # Only PEM blocks need to be ASCII; keep the original bytes for hashing.
    certs = [cert.decode("ascii") for cert in CERT_RE.findall(bundle_bytes)]
    if not certs:
        raise ValueError("No PEM certificates found")
    fingerprints = []
    for cert in certs:
        der = ssl.PEM_cert_to_DER_cert(cert)
        fingerprints.append(hashlib.sha256(der).hexdigest())
    if len(fingerprints) != len(set(fingerprints)):
        raise ValueError("Duplicate certificates in CA bundle")
    return certs, fingerprints, hashlib.sha256(bundle_bytes).hexdigest()


def create_keystore(bundle, keytool, target):
    certs, fingerprints, bundle_sha = parse_pem_bundle(bundle)
    if len(certs) < 50:
        raise ValueError("Unreasonably small root store; expected >= 50 certificates")
    target = Path(target)
    target.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="java7-certs-") as tmp:
        # The output keystore must not exist at the beginning of the first import.
        temporary_keystore = Path(tmp) / "cacerts"
        temporary_pem = Path(tmp) / "root.pem"
        for index, cert in enumerate(certs, start=1):
            temporary_pem.write_text(cert + "\n", encoding="ascii")
            proc = subprocess.run(
                [str(keytool), "-importcert", "-noprompt",
                 "-alias", "mozilla-%03d" % index,
                 "-file", str(temporary_pem),
                 "-keystore", str(temporary_keystore),
                 "-storetype", "JKS", "-storepass", "changeit"],
                stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True,
            )
            if proc.returncode:
                raise RuntimeError("keytool rejected root #%d: %s" % (index, proc.stdout))
        subprocess.run(
            [str(keytool), "-list", "-keystore", str(temporary_keystore),
             "-storetype", "JKS", "-storepass", "changeit"],
            check=True, stdout=subprocess.DEVNULL,
        )
        os.chmod(temporary_keystore, 0o644)
        # Copy only after all imports completed successfully.
        import shutil
        shutil.copyfile(str(temporary_keystore), str(target))
        os.chmod(target, 0o644)
    return {
        "ca_source": "https://curl.se/ca/cacert.pem",
        "ca_source_sha256": bundle_sha,
        "root_count": len(certs),
        "certificate_fingerprints_sha256": fingerprints,
        "keystore_type": "JKS",
        "policy_limitations": "Root certificates only; Mozilla per-domain trust and time-based distrust are not reproduced",
    }


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--bundle", type=Path, required=True)
    p.add_argument("--keytool", type=Path)
    p.add_argument("--keystore", type=Path)
    p.add_argument("--metadata", type=Path)
    p.add_argument("--check-only", action="store_true")
    args = p.parse_args()
    certs, _, bundle_sha = parse_pem_bundle(args.bundle)
    if len(certs) < 50:
        p.error("Refusing a trust store with fewer than 50 roots")
    if args.check_only:
        print("Bundle: %d roots, SHA256 %s" % (len(certs), bundle_sha))
        return
    if not args.keytool or not args.keystore:
        p.error("--keytool and --keystore required unless --check-only")
    data = create_keystore(args.bundle, args.keytool, args.keystore)
    if args.metadata:
        args.metadata.parent.mkdir(parents=True, exist_ok=True)
        args.metadata.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print("Created %s with %d roots" % (args.keystore, data["root_count"]))


if __name__ == "__main__":
    main()
