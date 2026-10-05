"""Fetch an explicitly pinned A3 blob for optional integration verification.

This script downloads text only. It does not execute the downloaded module.
"""

from __future__ import annotations

import base64
import hashlib
import json
from pathlib import Path
from urllib.request import Request, urlopen

ROOT = Path(__file__).resolve().parent
BLOB_SHA = "9b935fc2859632b0d24295bce34c31207efc364b"
SOURCE = f"https://api.github.com/repos/wndi1130-dot/APP/git/blobs/{BLOB_SHA}"


def main() -> None:
    request = Request(SOURCE, headers={"User-Agent": "B1-name-reference/1.0",
                                      "Accept": "application/vnd.github+json"})
    with urlopen(request, timeout=30) as response:
        payload = json.load(response)
    if payload.get("encoding") != "base64":
        raise SystemExit("[FAIL] 예상한 GitHub blob 인코딩이 아닙니다.")
    raw = base64.b64decode(payload["content"])
    raw.decode("utf-8")
    digest = hashlib.sha1(b"blob " + str(len(raw)).encode("ascii") + b"\0" + raw).hexdigest()
    if digest != BLOB_SHA:
        raise SystemExit("[FAIL] 고정한 A3 blob과 내려받은 파일이 다릅니다.")
    cache = ROOT / ".cache"
    cache.mkdir(exist_ok=True)
    (cache / "a3_gen_profiles.ts").write_bytes(raw)
    metadata = {"repository": "wndi1130-dot/APP", "branch": "codex/a3-profile-generator",
                "path": "s1/tools/gen_profiles.ts", "blob_sha": digest,
                "sha256": hashlib.sha256(raw).hexdigest(), "source": SOURCE}
    (cache / "a3-source.json").write_text(json.dumps(metadata, indent=2) + "\n", encoding="utf-8", newline="\n")
    print("[PASS] 고정한 A3 파일을 .cache/에 받았습니다. 코드는 실행하지 않았습니다.")


if __name__ == "__main__":
    main()
