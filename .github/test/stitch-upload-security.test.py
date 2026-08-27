import base64
import contextlib
import importlib.util
import io
import json
import os
import pathlib
import tempfile
import unittest
import unittest.mock
import urllib.error


ROOT = pathlib.Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "config/claude/skills/stitch-manage-design-system/scripts/upload_to_stitch.py"
SPEC = importlib.util.spec_from_file_location("upload_to_stitch", SCRIPT)
assert SPEC and SPEC.loader
UPLOAD = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(UPLOAD)


class Response:
    def __init__(self, body: bytes, url: str = UPLOAD.STITCH_ORIGIN, status: int = 200):
        self.body = body
        self.url = url
        self.status = status

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc_value, traceback):
        return False

    def getcode(self):
        return self.status

    def geturl(self):
        return self.url

    def read(self):
        return self.body


class StitchUploaderTests(unittest.TestCase):
    def test_main_returns_controlled_error_when_encoding_fails(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            file_path = pathlib.Path(temp_dir) / "design.md"
            file_path.write_text("# Design", encoding="utf-8")
            args = unittest.mock.Mock(
                project_id="project-123",
                file_path=file_path,
                generated_by=None,
                title=None,
            )
            output = io.StringIO()
            with unittest.mock.patch.object(UPLOAD, "parse_args", return_value=args):
                with unittest.mock.patch.dict(os.environ, {"STITCH_API_KEY": "secret"}, clear=True):
                    with unittest.mock.patch.object(
                        UPLOAD,
                        "encode_file",
                        side_effect=UPLOAD.StitchUploadError("input file could not be opened safely"),
                    ) as encode_file:
                        with unittest.mock.patch.object(UPLOAD, "call_batch_create_screens") as upload:
                            with contextlib.redirect_stdout(output):
                                result = UPLOAD.main()

            self.assertEqual(result, 1)
            self.assertIn("Error: input file could not be opened safely", output.getvalue())
            encode_file.assert_called_once_with(file_path)
            upload.assert_not_called()

    def test_default_transport_configures_https_handler_without_open_context(self):
        captured = {}

        class RecordingOpener:
            def open(self, request, **kwargs):
                captured["request"] = request
                captured["kwargs"] = kwargs
                return Response(json.dumps({"screen": "created"}).encode())

        ssl_context = object()
        with unittest.mock.patch.object(UPLOAD, "_SSL_CONTEXT", ssl_context):
            with unittest.mock.patch.object(
                UPLOAD.urllib.request, "build_opener", return_value=RecordingOpener()
            ) as build_opener:
                with unittest.mock.patch.dict(os.environ, {"STITCH_API_KEY": "secret"}, clear=False):
                    result = UPLOAD.call_batch_create_screens("project-123", [{"screen": {}}])

        self.assertEqual(result, {"screen": "created"})
        self.assertEqual(captured["kwargs"], {"timeout": 120})
        self.assertNotIn("context", captured["kwargs"])
        handlers = build_opener.call_args.args
        self.assertTrue(any(isinstance(handler, UPLOAD.urllib.request.HTTPSHandler) for handler in handlers))
        https_handler = next(
            handler for handler in handlers if isinstance(handler, UPLOAD.urllib.request.HTTPSHandler)
        )
        self.assertIs(https_handler._context, ssl_context)
        self.assertTrue(any(handler is UPLOAD._NoRedirectHandler for handler in handlers))

    def test_builds_fixed_origin_request_without_api_url_argument(self):
        captured = {}

        def fake_urlopen(request, **kwargs):
            captured["request"] = request
            captured["kwargs"] = kwargs
            return Response(json.dumps({"screen": "created"}).encode())

        request = UPLOAD.build_screen_request(
            "text/markdown", base64.b64encode(b"# Design").decode(), title="Design"
        )
        with unittest.mock.patch.dict(os.environ, {"STITCH_API_KEY": "secret"}, clear=False):
            result = UPLOAD.call_batch_create_screens(
                "project-123",
                [request],
                create_screen_instances=True,
                urlopen=fake_urlopen,
            )

        sent_headers = {key.lower(): value for key, value in captured["request"].header_items()}
        self.assertEqual(result, {"screen": "created"})
        self.assertEqual(
            captured["request"].full_url,
            "https://stitch.googleapis.com/v1/projects/project-123/screens:batchCreate",
        )
        self.assertEqual(sent_headers["x-goog-api-key"], "secret")
        self.assertEqual(captured["kwargs"]["timeout"], 120)
        self.assertEqual(json.loads(captured["request"].data)["createScreenInstances"], True)

    def test_rejects_missing_key_and_bad_project_id(self):
        request = {"screen": {}}
        with unittest.mock.patch.dict(os.environ, {}, clear=True):
            with self.assertRaisesRegex(UPLOAD.StitchUploadError, "STITCH_API_KEY"):
                UPLOAD.call_batch_create_screens("project-123", [request], urlopen=unittest.mock.Mock())

        with unittest.mock.patch.dict(os.environ, {"STITCH_API_KEY": "secret"}, clear=True):
            with self.assertRaises(UPLOAD.StitchUploadError):
                UPLOAD.call_batch_create_screens("project/escape", [request], urlopen=unittest.mock.Mock())

    def test_rejects_unsupported_symlink_nonregular_and_oversize_inputs(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            root = pathlib.Path(temp_dir)
            unsupported = root / "design.txt"
            unsupported.write_text("text", encoding="utf-8")
            with self.assertRaises(UPLOAD.StitchUploadError):
                UPLOAD.encode_file(unsupported)

            directory = root / "design.md"
            directory.mkdir()
            with self.assertRaises(UPLOAD.StitchUploadError):
                UPLOAD.encode_file(directory)

            oversized = root / "large.md"
            with oversized.open("wb") as file_handle:
                file_handle.truncate(UPLOAD.MAX_FILE_SIZE + 1)
            with self.assertRaises(UPLOAD.StitchUploadError):
                UPLOAD.encode_file(oversized)

            target = root / "target.md"
            target.write_text("markdown", encoding="utf-8")
            symlink = root / "link.md"
            os.symlink(target, symlink)
            with self.assertRaisesRegex(UPLOAD.StitchUploadError, "symlink"):
                UPLOAD.encode_file(symlink)

    def test_rejects_redirect_http_url_and_json_errors_without_key_in_error(self):
        with unittest.mock.patch.dict(os.environ, {"STITCH_API_KEY": "secret"}, clear=True):
            request = {"screen": {}}

            with self.assertRaisesRegex(UPLOAD.StitchUploadError, "redirect") as redirect_error:
                UPLOAD.call_batch_create_screens(
                    "project-123",
                    [request],
                    urlopen=lambda *_args, **_kwargs: Response(
                        b"{}", "https://evil.invalid/redirect"
                    ),
                )
            self.assertNotIn("secret", str(redirect_error.exception))

            http_error = urllib.error.HTTPError(
                "https://stitch.googleapis.com/", 503, "secret response", {}, io.BytesIO(b"secret")
            )
            with self.assertRaisesRegex(UPLOAD.StitchUploadError, "503") as http_failure:
                UPLOAD.call_batch_create_screens(
                    "project-123", [request], urlopen=lambda *_args, **_kwargs: (_ for _ in ()).throw(http_error)
                )
            self.assertNotIn("secret", str(http_failure.exception))

            with self.assertRaisesRegex(UPLOAD.StitchUploadError, "invalid JSON"):
                UPLOAD.call_batch_create_screens(
                    "project-123", [request], urlopen=lambda *_args, **_kwargs: Response(b"not json")
                )

            with self.assertRaisesRegex(UPLOAD.StitchUploadError, "could not reach"):
                UPLOAD.call_batch_create_screens(
                    "project-123",
                    [request],
                    urlopen=lambda *_args, **_kwargs: (_ for _ in ()).throw(
                        urllib.error.URLError("secret network detail")
                    ),
                )


if __name__ == "__main__":
    unittest.main()
