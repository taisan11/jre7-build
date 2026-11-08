#!/usr/bin/env python3
"""Verify the contents of the Java 7 ZIPs before upload/release."""

import argparse
from pathlib import Path
import re
from zipfile import BadZipFile, ZipFile


ARCHIVE_NAME = re.compile(r'legacy-openjdk7u351-(linux|windows)-x64-(jdk|jre)\.zip')


def verify_archive(path: Path) -> None:
    match = ARCHIVE_NAME.fullmatch(path.name)
    if match is None:
        raise ValueError(f'Unexpected archive name: {path.name}')

    platform, kind = match.groups()
    exe = '.exe' if platform == 'windows' else ''
    root = path.stem
    required = {
        f'{root}/bin/java{exe}',
        f'{root}/bin/keytool{exe}',
        f'{root}/lib/security/cacerts' if kind == 'jre' else f'{root}/jre/lib/security/cacerts',
    }
    if kind == 'jdk':
        required.update({
            f'{root}/bin/javac{exe}',
            f'{root}/lib/tools.jar',
            f'{root}/jre/bin/java{exe}',
        })

    with ZipFile(path) as archive:
        present = {item.filename.replace('\\', '/') for item in archive.infolist() if not item.is_dir()}
    missing = sorted(required - present)
    if missing:
        raise ValueError(f'{path.name} is missing required files: {", ".join(missing)}')
    print(f'Verified {path.name}: {kind.upper()} files are present')


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('archives', nargs='+', type=Path)
    args = parser.parse_args()
    for path in args.archives:
        try:
            verify_archive(path)
        except (OSError, ValueError, BadZipFile) as exc:
            parser.exit(1, f'ERROR: {exc}\n')


if __name__ == '__main__':
    main()
