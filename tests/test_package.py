import os
from pathlib import Path
import subprocess
import tempfile
import unittest


PACKAGE = Path(__file__).resolve().parents[1] / 'scripts' / 'package.sh'


@unittest.skipUnless(os.name == 'posix', 'Linux packaging requires POSIX tools')
class PackagePathTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.src = self.root / 'work' / 'openjdk'
        self.out = self.root / 'out'
        self.src.mkdir(parents=True)
        self.out.mkdir()
        (self.src / 'LICENSE').write_text('license')
        (self.root / 'work' / 'cacert.pem').write_text('bundle')
        (self.root / 'work' / 'cacert.sha256').write_text('1234  cacert.pem\n')
        (self.root / 'work' / 'upstream-commit.txt').write_text('commit\n')
        (self.root / 'work' / 'applied-patches.txt').write_text('none\n')
        self.bin = self.root / 'mock-bin'
        self.bin.mkdir()
        self.executable(self.bin / 'python3', 'exit 0')
        self.executable(self.bin / 'zip', 'echo archive > "$5"')

    def executable(self, path, body):
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text('#!/bin/bash\n' + body + '\n')
        path.chmod(0o755)

    def run_package(self, path):
        (self.out / 'jdk-image-path.txt').write_text(path + '\n')
        return subprocess.run(
            ['bash', str(PACKAGE), str(self.src), str(self.out),
             str(self.root / 'work' / 'cacert.pem'), 'ref', 'commit', 'run',
             str(self.root / 'work' / 'cacert.sha256')],
            cwd=self.root, env={**os.environ, 'PATH': str(self.bin) + os.pathsep + os.environ['PATH']},
            text=True, capture_output=True)

    def test_source_relative_path_is_resolved_on_host(self):
        image = self.src / 'build' / 'linux-amd64' / 'j2sdk-image'
        self.executable(image / 'bin' / 'keytool', 'exit 0')
        # Packaging now compiles SecuritySmokeTest using the built JDK.
        self.executable(image / 'bin' / 'javac', 'exit 0')
        self.executable(image / 'bin' / 'java', 'exit 0')
        self.executable(image / 'jre' / 'bin' / 'java', 'exit 0')
        result = self.run_package('build/linux-amd64/j2sdk-image')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue((self.out / 'legacy-openjdk7u351-linux-x64-jdk.zip').exists(), result.stderr)
        self.assertTrue((self.out / 'legacy-openjdk7u351-linux-x64-jre.zip').exists(), result.stderr)

    def test_absolute_and_escaping_paths_are_rejected(self):
        for path in ('/work/openjdk/build/image', '../outside'):
            with self.subTest(path=path):
                result = self.run_package(path)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn('path', result.stderr)


if __name__ == '__main__':
    unittest.main()
