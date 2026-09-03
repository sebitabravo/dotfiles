import importlib.util
import io
import pathlib
import stat
import tempfile
import unittest
import zipfile


ROOT = pathlib.Path(__file__).resolve().parents[2]
HELPER_PATHS = [
    ROOT / "config/claude/skills/pptx/scripts/office/helpers/__init__.py",
    ROOT / "config/claude/skills/xlsx/scripts/office/helpers/__init__.py",
]
UNPACK_PATHS = [
    ROOT / "config/claude/skills/pptx/scripts/office/unpack.py",
    ROOT / "config/claude/skills/xlsx/scripts/office/unpack.py",
]


def load_helper(path: pathlib.Path, name: str):
    spec = importlib.util.spec_from_file_location(name, path)
    assert spec and spec.loader
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class FakeZip:
    def __init__(self, members):
        self.members = members
        self.extracted = []

    def infolist(self):
        return self.members

    def extract(self, member, destination):
        self.extracted.append((member, destination))


def member(name, file_size=0, compress_size=1):
    info = zipfile.ZipInfo(name)
    info.file_size = file_size
    info.compress_size = compress_size
    return info


class SafeExtractTests(unittest.TestCase):
    def test_both_helpers_reject_traversal_and_symlinks_before_extracting(self):
        for index, path in enumerate(HELPER_PATHS):
            helper = load_helper(path, f"office_helpers_traversal_{index}")
            with self.subTest(helper=path):
                archive = FakeZip([member("../escape.txt", file_size=1)])
                with tempfile.TemporaryDirectory() as destination:
                    with self.assertRaisesRegex(ValueError, "unsafe archive entry"):
                        helper.safe_extract(archive, pathlib.Path(destination))
                self.assertEqual(archive.extracted, [])

                symlink = member("link", file_size=1)
                symlink.external_attr = stat.S_IFLNK << 16
                archive = FakeZip([symlink])
                with tempfile.TemporaryDirectory() as destination:
                    with self.assertRaisesRegex(ValueError, "symlink archive entry"):
                        helper.safe_extract(archive, pathlib.Path(destination))
                self.assertEqual(archive.extracted, [])

    def test_both_helpers_enforce_entry_size_total_and_ratio_limits(self):
        for index, path in enumerate(HELPER_PATHS):
            helper = load_helper(path, f"office_helpers_limits_{index}")
            with self.subTest(helper=path):
                cases = [
                    (
                        [member(str(i)) for i in range(helper.MAX_ARCHIVE_ENTRIES + 1)],
                        "too many entries",
                    ),
                    (
                        [
                            member(
                                "large.bin",
                                helper.MAX_ENTRY_UNCOMPRESSED_SIZE + 1,
                                helper.MAX_ENTRY_UNCOMPRESSED_SIZE + 1,
                            )
                        ],
                        "entry is too large",
                    ),
                    (
                        [
                            member(
                                f"part-{i}",
                                helper.MAX_ENTRY_UNCOMPRESSED_SIZE,
                                helper.MAX_ENTRY_UNCOMPRESSED_SIZE,
                            )
                            for i in range(5)
                        ],
                        "too large when uncompressed",
                    ),
                    (
                        [member("bomb.bin", helper.MAX_COMPRESSION_RATIO + 1, 1)],
                        "suspicious compression ratio",
                    ),
                ]
                for members, message in cases:
                    archive = FakeZip(members)
                    with tempfile.TemporaryDirectory() as destination:
                        with self.assertRaisesRegex(ValueError, message):
                            helper.safe_extract(archive, pathlib.Path(destination))
                    self.assertEqual(archive.extracted, [])

    def test_both_helpers_extract_a_normal_archive(self):
        for index, path in enumerate(HELPER_PATHS):
            helper = load_helper(path, f"office_helpers_normal_{index}")
            with self.subTest(helper=path), tempfile.TemporaryDirectory() as destination:
                buffer = io.BytesIO()
                with zipfile.ZipFile(buffer, "w", zipfile.ZIP_DEFLATED) as archive:
                    archive.writestr("word/document.xml", "<document>ok</document>")
                    archive.writestr("[Content_Types].xml", "<types />")
                buffer.seek(0)
                with zipfile.ZipFile(buffer, "r") as archive:
                    helper.safe_extract(archive, pathlib.Path(destination))
                self.assertEqual(
                    (pathlib.Path(destination) / "word/document.xml").read_text(),
                    "<document>ok</document>",
                )

    def test_unpackers_use_safe_extract(self):
        for path in UNPACK_PATHS:
            source = path.read_text(encoding="utf-8")
            self.assertIn("safe_extract(zf, output_path)", source)
            self.assertNotIn(".extractall(", source)


if __name__ == "__main__":
    unittest.main()
