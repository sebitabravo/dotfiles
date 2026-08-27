#!/usr/bin/env python3
r"""Upload an image, HTML, or Markdown file to a Stitch project via BatchCreateScreens.

WHY THIS SCRIPT EXISTS:
    The AI model cannot upload files via the MCP tool directly because MCP tool
    call arguments are part of the model's *output*. The model must re-emit the
    entire base64-encoded file as generated text, but its output token limit
    (~16K tokens) is far smaller than a typical file's base64 encoding (e.g.
    a 53KB PNG becomes ~71K chars of base64). The output gets truncated
    mid-string, producing a corrupted payload that the API rejects.

    This script bypasses the model entirely — it reads the file, encodes it
    in-process, and sends the full payload directly over HTTP with no token
    limits.

SUPPORTED FILE TYPES:
    - Images: .png, .jpg, .jpeg, .webp
    - HTML: .html, .htm
    - Markdown: .md

Usage:
    export STITCH_API_KEY
    python3 upload_to_stitch.py \
        --project-id <PROJECT_ID> \
        --file-path <PATH_TO_FILE> \
        [--title <SCREEN_TITLE>] \
        [--generated-by <GENERATED_BY>]
"""

import argparse
import base64
import json
import os
import pathlib
import re
import stat
import sys
from typing import Any
import urllib.error
import urllib.parse
import urllib.request

try:
  import ssl
  import certifi
  _SSL_CONTEXT = ssl.create_default_context(cafile=certifi.where())
except ImportError:
  _SSL_CONTEXT = None


# Maps file extensions to MIME types.
_MIME_TYPES = {
    ".png": "image/png",
    ".jpg": "image/jpeg",
    ".jpeg": "image/jpeg",
    ".webp": "image/webp",
    ".html": "text/html",
    ".htm": "text/html",
    ".md": "text/markdown",
}


STITCH_ORIGIN = "https://stitch.googleapis.com"
MAX_FILE_SIZE = 10 * 1024 * 1024
_PROJECT_ID_RE = re.compile(r"[A-Za-z0-9][A-Za-z0-9._-]{0,127}\Z")


class StitchUploadError(ValueError):
  """A safe, user-facing uploader error that never includes credentials."""


class _NoRedirectHandler(urllib.request.HTTPRedirectHandler):
  def redirect_request(self, req, fp, code, msg, headers, new):
    raise StitchUploadError("redirect rejected; Stitch uploads must stay on the fixed origin")


def _urlopen_no_redirect(request: urllib.request.Request, **kwargs: Any):
  handlers = [_NoRedirectHandler]
  if _SSL_CONTEXT is not None:
    handlers.insert(0, urllib.request.HTTPSHandler(context=_SSL_CONTEXT))
  opener = urllib.request.build_opener(*handlers)
  return opener.open(request, **kwargs)


def validate_project_id(project_id: str) -> str:
  """Accept only a bounded, safe single path component."""
  if not _PROJECT_ID_RE.fullmatch(project_id):
    raise StitchUploadError("invalid project ID; expected one safe path component")
  return project_id


def validate_upload_file(path: pathlib.Path) -> tuple[pathlib.Path, str]:
  """Validate an upload before opening or base64-encoding it."""
  suffix = path.suffix.lower()
  mime_type = _MIME_TYPES.get(suffix)
  if mime_type is None:
    raise StitchUploadError(
        f"unsupported file type '{suffix}'. Supported types: "
        f"{', '.join(sorted(_MIME_TYPES.keys()))}"
    )

  try:
    file_stat = os.lstat(path)
  except FileNotFoundError:
    raise StitchUploadError(f"file not found: {path}") from None
  except OSError:
    raise StitchUploadError("file could not be inspected") from None

  if stat.S_ISLNK(file_stat.st_mode):
    raise StitchUploadError("symlink input files are not allowed")
  if not stat.S_ISREG(file_stat.st_mode):
    raise StitchUploadError("input path must be a regular file")
  if file_stat.st_size > MAX_FILE_SIZE:
    raise StitchUploadError(f"input file exceeds the {MAX_FILE_SIZE}-byte limit")
  return path, mime_type


def encode_file(path: pathlib.Path) -> str:
  """Read and base64-encode a file."""
  validate_upload_file(path)
  flags = os.O_RDONLY
  if hasattr(os, "O_NOFOLLOW"):
    flags |= os.O_NOFOLLOW
  try:
    fd = os.open(path, flags)
  except OSError:
    raise StitchUploadError("input file could not be opened safely") from None
  with os.fdopen(fd, "rb") as file_handle:
    file_stat = os.fstat(file_handle.fileno())
    if not stat.S_ISREG(file_stat.st_mode):
      raise StitchUploadError("input path must be a regular file")
    if file_stat.st_size > MAX_FILE_SIZE:
      raise StitchUploadError(f"input file exceeds the {MAX_FILE_SIZE}-byte limit")
    content = file_handle.read(MAX_FILE_SIZE + 1)
    if len(content) > MAX_FILE_SIZE:
      raise StitchUploadError(f"input file exceeds the {MAX_FILE_SIZE}-byte limit")
  return base64.b64encode(content).decode("utf-8")


def call_batch_create_screens(
    project_id: str,
    requests: list[dict[str, Any]],
    create_screen_instances: bool = False,
    urlopen: Any = None,
) -> dict[str, Any]:
  """Call BatchCreateScreens REST API directly.

  Endpoint: POST /v1/{parent=projects/*}/screens:batchCreate

  Args:
    project_id: The Stitch project ID.
    requests: List of CreateScreenRequest dicts, each containing a screen.
    create_screen_instances: Whether to create screen instances for display.
    urlopen: The urlopen function to use (for testing).

  Returns:
    Parsed JSON response dict.
  """
  validate_project_id(project_id)
  api_key = os.environ.get("STITCH_API_KEY", "")
  if not api_key.strip():
    raise StitchUploadError("STITCH_API_KEY is required and must not be empty")
  url = f"{STITCH_ORIGIN}/v1/projects/{project_id}/screens:batchCreate"

  payload = {
      "parent": f"projects/{project_id}",
      "requests": requests,
      "createScreenInstances": create_screen_instances,
  }

  data = json.dumps(payload).encode("utf-8")
  req = urllib.request.Request(
      url,
      data=data,
      headers={
          "Content-Type": "application/json",
          "X-Goog-Api-Key": api_key,
      },
      method="POST",
  )

  try:
    opener = urlopen or _urlopen_no_redirect
    urlopen_kwargs = {"timeout": 120}
    with opener(req, **urlopen_kwargs) as resp:
      final_url = getattr(resp, "geturl", lambda: url)()
      parsed_url = urllib.parse.urlsplit(final_url)
      if parsed_url.scheme != "https" or parsed_url.netloc != "stitch.googleapis.com":
        raise StitchUploadError("redirect rejected; response left the fixed Stitch origin")
      status = resp.getcode()
      if status is not None and 300 <= status < 400:
        raise StitchUploadError("redirect rejected; Stitch uploads do not follow redirects")
      if status is not None and status >= 400:
        raise StitchUploadError(f"Stitch request failed with HTTP status {status}")
      body = resp.read().decode("utf-8")
      if not body:
        raise StitchUploadError("Stitch request returned an empty response")
      try:
        result = json.loads(body)
      except json.JSONDecodeError:
        raise StitchUploadError("Stitch request returned invalid JSON") from None
      if not isinstance(result, dict):
        raise StitchUploadError("Stitch request returned an unexpected JSON value")
      return result
  except StitchUploadError:
    raise
  except urllib.error.HTTPError as exc:
    raise StitchUploadError(f"Stitch request failed with HTTP status {exc.code}") from None
  except urllib.error.URLError:
    raise StitchUploadError("Stitch request could not reach the fixed origin") from None
  except (UnicodeDecodeError, OSError):
    raise StitchUploadError("Stitch response could not be read") from None


def build_screen_request(
    mime_type: str,
    b64_data: str,
    title: str | None = None,
    generated_by: str | None = None,
) -> dict[str, Any]:
  """Build a CreateScreenRequest dict from a file.

  For images, the file is set as the screenshot.
  For HTML, the file is set as the html_code.

  Args:
    mime_type: The MIME type of the file.
    b64_data: Base64-encoded file content.
    title: Optional title for the screen.
    generated_by: Optional value for the generatedBy field (HTML/markdown only).

  Returns:
    A CreateScreenRequest-shaped dict.
  """
  file_obj = {
      "fileContentBase64": b64_data,
      "mimeType": mime_type,
  }

  if mime_type in ("text/html", "text/markdown"):
    screen = {
        "htmlCode": file_obj,
        "screenType": "DOCUMENT",
        "isCreatedByClient": True,
    }
    if not generated_by:
      if mime_type == "text/markdown":
        generated_by = "UserUploadedDesignMd"
      elif mime_type == "text/html":
        generated_by = "UserUploadedHtml"
    if generated_by:
      screen["generatedBy"] = generated_by
  else:
    screen = {
        "screenshot": file_obj,
        "screenType": "IMAGE",
        "isCreatedByClient": True,
    }

  if title:
    screen["title"] = title

  return {"screen": screen}


def parse_args():
  """Parse command-line arguments."""
  parser = argparse.ArgumentParser(
      description="Upload a file to a Stitch project via BatchCreateScreens."
  )
  parser.add_argument("--project-id", required=True, help="Stitch project ID")
  parser.add_argument(
      "--file-path",
      required=True,
      type=pathlib.Path,
      help=(
          "Path to the file to upload. Supported types:"
          f" {', '.join(sorted(_MIME_TYPES.keys()))}"
      ),
  )
  parser.add_argument(
      "--title",
      default=None,
      help="Optional title for the created screen",
  )
  parser.add_argument(
      "--generated-by",
      default=None,
      help=(
          "Value for the generatedBy field in the screen proto"
          " (HTML/markdown uploads only)."
      ),
  )
  return parser.parse_args()


def main():
  args = parse_args()

  file_path = args.file_path
  try:
    validate_project_id(args.project_id)
    _, mime_type = validate_upload_file(file_path)
    if not os.environ.get("STITCH_API_KEY", "").strip():
      raise StitchUploadError("STITCH_API_KEY is required and must not be empty")
  except StitchUploadError as exc:
    print(f"Error: {exc}")
    return 1

  if args.generated_by and mime_type not in ("text/html", "text/markdown"):
    print("Warning: --generated-by is ignored for image uploads.")

  print(f"File:      {file_path}")
  print(f"MIME type: {mime_type}")

  try:
    b64_data = encode_file(file_path)
  except StitchUploadError as exc:
    print(f"Error: {exc}")
    return 1
  print(f"Base64:    {len(b64_data)} chars")

  screen_request = build_screen_request(
      mime_type, b64_data, title=args.title, generated_by=args.generated_by,
  )

  print(f"\nUploading to project: {args.project_id}")

  try:
    result = call_batch_create_screens(
        project_id=args.project_id,
        requests=[screen_request],
        create_screen_instances=True,
    )
  except StitchUploadError as exc:
    print(f"Error: {exc}")
    return 1

  print("\nResponse:")
  print(json.dumps(result, indent=2))
  return 0


if __name__ == "__main__":
  sys.exit(main())
