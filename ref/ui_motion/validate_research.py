"""Validate authored UI research metadata. Standard library; no network or game execution."""
from __future__ import annotations

import json
import re
from pathlib import Path
from urllib.parse import unquote, urlsplit

HERE = Path(__file__).resolve().parent
BASE = "20a2728fdd737e56ae2d08d63e657172c616d4e7"
SOURCE_KINDS = {
    "developer_article", "developer_breakdown", "developer_portfolio",
    "developer_case_study", "publisher_listing", "official_video_transcript",
    "publisher_release", "independent_analysis", "composer_interview",
    "official_documentation", "library_readme", "sound_pack_listing",
    "project_document", "discovery_lead",
}


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def valid_url(value: str) -> bool:
    try:
        parts = urlsplit(value)
        return (parts.scheme == "https" and bool(parts.hostname)
                and not parts.username and not parts.password)
    except (TypeError, ValueError):
        return False


def load(folder: Path = HERE) -> tuple[dict, dict, dict]:
    return tuple(json.loads((folder / name).read_text(encoding="utf-8"))
                 for name in ("sources.json", "event_matrix.json", "capture_plan.json"))


def validate_data(registry: dict, matrix: dict, capture: dict) -> dict[str, int]:
    require(registry.get("base_commit") == BASE, "Unexpected research base")
    sources: dict[str, dict] = {}
    for row in registry["sources"]:
        sid = row.get("id", "")
        require(bool(re.fullmatch(r"[GTPAL]\d{2}", sid)), "Invalid source ID")
        require(sid not in sources, "Duplicate source ID")
        sources[sid] = row
        require(row.get("kind") in SOURCE_KINDS, "Invalid source kind")
        require(valid_url(row.get("url", "")), "Invalid source URL")
        for key in ("title", "author", "access", "confirmed", "limits", "rights", "checked_on"):
            require(bool(row.get(key)), "Missing source " + key)
        for flag in ("video_playback_verified", "audio_listened", "assets_downloaded"):
            require(row.get(flag) is False, "Unsubstantiated source execution")
    # The independent analyst's reconstruction must not become developer testimony.
    require(sources.get("G10", {}).get("kind") == "independent_analysis",
            "Independent analysis reclassified")
    for sid in ("L01", "L02"):
        require(sources.get(sid, {}).get("kind") == "discovery_lead", "Unverified lead reclassified")

    require(bool(matrix.get("timing_note")), "Missing timing qualification")
    cues: set[str] = set()
    for row in matrix["sound_cues"]:
        cid = row.get("id", "")
        require(bool(cid) and cid not in cues, "Duplicate or empty cue ID")
        cues.add(cid)
        for key in ("purpose", "recipe_proposal", "limits", "source_ids"):
            require(bool(row.get(key)), "Missing cue " + key)
        require(set(row["source_ids"]) <= sources.keys(), "Unknown cue source")
        require(row.get("selected_audio_file") is None and row.get("audio_listened") is False,
                "Unsubstantiated selected audio")
        require(row.get("status") == "[WATCH]", "Unverified audio marked passed")
    events: set[str] = set()
    for row in matrix["events"]:
        eid = row.get("id", "")
        require(bool(eid) and eid not in events, "Duplicate or empty event ID")
        events.add(eid)
        for key in ("title", "trigger", "visual", "commit_rule", "repeat_rule", "cancel_rule",
                    "reduced_motion", "inspiration_sources"):
            require(bool(row.get(key)), "Missing event " + key)
        require(row.get("evidence_level") == "project_proposal", "Proposal misrepresented as observation")
        require(row.get("observed_in_original") is False and row.get("runtime_tested") is False,
                "Unsubstantiated event execution")
        require(row.get("sound_cue") == "none" or row.get("sound_cue") in cues, "Unknown sound cue")
        require(set(row["inspiration_sources"]) <= sources.keys(), "Unknown event source")
        duration = row.get("duration_ms_proposal")
        require(isinstance(duration, list) and len(duration) == 2
                and all(type(v) is int for v in duration) and 0 <= duration[0] <= duration[1],
                "Invalid proposed duration")
        require(row.get("clock") in {"ui_unscaled", "game_progress_ui_decoration"}, "Unknown clock")

    # These are author-provided chapter/credit locations, NOT measured game animation timings.
    declared = {("G10", 193, 260, "author_chapters"), ("G10", 360, 423, "author_chapters"),
                ("G10", 424, 553, "author_chapters"), ("G10", 554, 626, "author_chapters"),
                ("G03", 54, 60, "author_credit")}
    seen_checkpoints: set[tuple] = set()
    for row in capture["checkpoints"]:
        key = (row.get("source_id"), row.get("start_seconds"), row.get("end_seconds"), row.get("time_basis"))
        require(key in declared and key not in seen_checkpoints, "Unsupported or duplicate checkpoint")
        seen_checkpoints.add(key)
        require(valid_url(row.get("url", "")), "Invalid checkpoint URL")
        require(row.get("directly_observed") is False and row.get("audio_listened") is False,
                "Unsubstantiated checkpoint playback")
    missing_ids: set[str] = set()
    for row in capture["missing_original_checks"]:
        require(row.get("id") not in missing_ids, "Duplicate missing-observation ID")
        missing_ids.add(row["id"])
        require(row.get("source_id") in sources, "Unknown observation reference")
        for key in ("recording_url", "build", "platform", "timestamp_start", "timestamp_end"):
            require(row.get(key) is None, "Invented original observation value")
        require(row.get("directly_observed") is False and row.get("raw_audio_acquired") is False,
                "Unsubstantiated original observation")
        require(row.get("status") == "[WATCH]", "Missing observation marked passed")
    return {"source_records": len(sources), "discovery_leads": sum(s["kind"] == "discovery_lead" for s in sources.values()),
            "event_proposals": len(events), "sound_cue_intents": len(cues),
            "author_checkpoints": len(seen_checkpoints), "missing_observation_records": len(missing_ids)}


def validate_documents(folder: Path = HERE) -> int:
    """Check local file/explicit-anchor references, not availability of external URLs."""
    folder = folder.resolve()
    count = 0
    for path in sorted(folder.glob("*.md")):
        text = path.read_text(encoding="utf-8")
        require(all(line == line.rstrip() for line in text.splitlines()), "Trailing whitespace: " + path.name)
        require("\x00" not in text, "Unexpected binary content")
        for target in re.findall(r"\]\(([^)]+)\)", text):
            if "://" in target:
                continue
            relative, _, anchor = unquote(target).partition("#")
            destination = (path.parent / relative).resolve() if relative else path
            require(destination.is_relative_to(folder) and destination.is_file(), "Broken or escaping local link")
            if anchor:
                target_text = destination.read_text(encoding="utf-8")
                require(f'id="{anchor}"' in target_text, "Missing explicit local anchor")
            count += 1
    sources, events, _ = load(folder)
    register = (folder / "sources.md").read_text(encoding="utf-8")
    for row in sources["sources"]:
        require(f'id="{row["id"].lower()}"' in register and row["url"] in register,
                "Source register mismatch")
        require(row["confirmed"] in register and row["limits"] in register, "Source summary mismatch")
    event_text = (folder / "event_matrix.md").read_text(encoding="utf-8")
    for row in events["events"]:
        require(f'id="{row["id"].lower()}"' in event_text and row["visual"] in event_text,
                "Event table mismatch")
    return count


def main() -> None:
    counts = validate_data(*load())
    counts["local_link_occurrences"] = validate_documents()
    print("[PASS] " + json.dumps(counts, ensure_ascii=False, sort_keys=True))
    print("[WATCH] No video/audio playback, external availability sweep, package/license clearance, or game/device test")


if __name__ == "__main__":
    main()
