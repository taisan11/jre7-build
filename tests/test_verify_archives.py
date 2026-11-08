import importlib.util
from pathlib import Path
import tempfile
import unittest
from zipfile import ZipFile


SPEC = importlib.util.spec_from_file_location(
    'verify_archives', Path(__file__).resolve().parents[1] / 'scripts' / 'verify_archives.py'
)
verify_archives = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(verify_archives)


class VerifyArchivesTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)

    def make_archive(self, platform, kind, missing=None):
        name = f'legacy-openjdk7u351-{platform}-x64-{kind}'
        extension = '.exe' if platform == 'windows' else ''
        expected = {
            f'{name}/bin/java{extension}',
            f'{name}/bin/keytool{extension}',
            f'{name}/lib/security/cacerts' if kind == 'jre'
            else f'{name}/jre/lib/security/cacerts',
        }
        if kind == 'jdk':
            expected |= {
                f'{name}/bin/javac{extension}',
                f'{name}/lib/tools.jar',
                f'{name}/jre/bin/java{extension}',
            }
        archive = self.root / f'{name}.zip'
        with ZipFile(archive, 'w') as file:
            for entry in expected - (missing or set()):
                file.writestr(entry, 'test')
        return archive

    def test_full_archives_pass(self):
        for platform in ('linux', 'windows'):
            for kind in ('jdk', 'jre'):
                with self.subTest(platform=platform, kind=kind):
                    verify_archives.verify_archive(self.make_archive(platform, kind))

    def test_jdk_missing_javac_fails(self):
        for platform, executable in (('linux', 'javac'), ('windows', 'javac.exe')):
            name = f'legacy-openjdk7u351-{platform}-x64-jdk'
            archive = self.make_archive(platform, 'jdk', {f'{name}/bin/{executable}'})
            with self.subTest(platform=platform), self.assertRaisesRegex(ValueError, executable):
                verify_archives.verify_archive(archive)

    def test_jdk_missing_tools_jar_fails(self):
        name = 'legacy-openjdk7u351-windows-x64-jdk'
        archive = self.make_archive('windows', 'jdk', {f'{name}/lib/tools.jar'})
        with self.assertRaisesRegex(ValueError, 'tools.jar'):
            verify_archives.verify_archive(archive)

    def test_wrong_top_level_folder_fails(self):
        archive = self.root / 'legacy-openjdk7u351-windows-x64-jdk.zip'
        with ZipFile(archive, 'w') as file:
            file.writestr('wrong/bin/javac.exe', 'test')
        with self.assertRaisesRegex(ValueError, 'missing required files'):
            verify_archives.verify_archive(archive)


if __name__ == '__main__':
    unittest.main()
