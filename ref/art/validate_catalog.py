"""Validate research metadata and active guidance; no network or Blender execution."""
from __future__ import annotations
import hashlib
import json
import re
from pathlib import Path
from urllib.parse import urlsplit, unquote

ROOT = Path(__file__).resolve().parents[2]
INDEX = ROOT / "ref/art/resource_index.json"
ALLOWED = {"[PASS]", "[WATCH]", "[PATCH REQUIRED]", "[FAIL]", "[BLOCKED]"}

def check(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)

def main() -> None:
    data = json.loads(INDEX.read_text(encoding="utf-8"))
    records = data["resources"]
    seen: set[str] = set()
    for row in records:
        check(bool(re.fullmatch(r"[a-z][a-z0-9_]*", row["id"])), "Invalid ID")
        check(row["id"] not in seen, "Duplicate ID: " + row["id"])
        seen.add(row["id"])
        check(row["status"] in ALLOWED, "Invalid status")
        check(row["project_runtime_tested"] is False, "Unsubstantiated runtime test")
        for key in ("name", "project_use", "source_supported", "license_and_distribution",
                    "publisher_compatibility", "limitations", "next_test", "sources"):
            check(bool(row[key]), f"Missing {key}: {row['id']}")
        for url in row["sources"]:
            check(urlsplit(url).scheme == "https" and bool(urlsplit(url).netloc), "Invalid source URL")
    for row in data["excluded"]:
        check(row["id"] not in seen, "Duplicate excluded ID")
        seen.add(row["id"])
        check(row["status"] == "[BLOCKED]", "Invalid exclusion status")
    active = ["CLAUDE.md", "README.md", "docs/handoff/session_start.md",
              "docs/design/decisions.md", "docs/art/production_brief.md",
              "docs/art/image_prompts.md", "docs/handoff/3d_research_tasks.md",
              "docs/prototype/s1_political_prototype.md", "ref/art/production_resources.md"]
    forbidden = ["세계는 픽셀 아트로 두고", "그림은 옆 스크롤 픽셀 아트로 한다",
                 "The whole image uses one uniform pixel size", "no arrows or faces predicting"]
    local_links = 0
    for path in active:
        text = (ROOT / path).read_text(encoding="utf-8")
        for phrase in forbidden:
            check(phrase not in text, f"Retired live instruction in {path}: {phrase}")
        for target in re.findall(r"\]\(([^)]+)\)", text):
            if "://" in target or target.startswith("#"):
                continue
            target = unquote(target.split("#", 1)[0])
            if not target:
                continue
            check(((ROOT / path).parent / target).exists(), f"Broken local link: {path} -> {target}")
            local_links += 1
    art = (ROOT / "docs/art/image_prompts.md").read_text(encoding="utf-8")
    check("left half" in art and "discrete detents" in art, "Updated layout missing")
    decisions = (ROOT / "docs/design/decisions.md").read_text(encoding="utf-8")
    check("좀보이드식 그래픽" in decisions, "World correction missing")
    archive = (ROOT / "docs/art/image_prompts_20261006_archived.md").read_text(encoding="utf-8")
    marker = "<!-- ORIGINAL_20261006_BELOW -->\n"
    check(marker in archive, "Archive marker missing")
    body = archive.split(marker, 1)[1]
    expected = (ROOT / "ref/art/archive_manifest.json").read_text(encoding="utf-8")
    check(hashlib.sha256(body.encode("utf-8")).hexdigest() == json.loads(expected)["original_utf8_lf_sha256"],
          "Historical prompt body was changed")
    new = sum(bool(x["new_in_v2"]) for x in records)
    print(f"[PASS] {len(records)} resources; {new} new; {len(data['excluded'])} exclusions")
    print(f"[PASS] IDs, required fields, {local_links} local links, active guidance and preserved archive")
    print("[WATCH] No external URL, license/legal, Blender, Unity, or mobile runtime validation")

if __name__ == "__main__":
    main()
