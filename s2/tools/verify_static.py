"""Offline structural checks only; this is not a Godot/GDScript parser."""
from __future__ import annotations

import configparser
import hashlib
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PROJECT = ROOT / "s2"
WORKFLOW = ROOT / ".github/workflows/s2-android.yml"
OUT = PROJECT / "verification"


def check_delimiters(path: Path, source: str) -> None:
    stack: list[str] = []
    pairs = {"(": ")", "[": "]", "{": "}"}
    quote = ""
    escaped = False
    for line in source.splitlines():
        i = 0
        while i < len(line):
            char = line[i]
            if quote:
                if escaped:
                    escaped = False
                elif char == "\\":
                    escaped = True
                elif char == quote:
                    quote = ""
            elif char in "\"'":
                quote = char
            elif char == "#" or line[i:i + 2] == "//":
                break
            elif char in pairs:
                stack.append(pairs[char])
            elif char in ")]}":
                assert stack and stack.pop() == char, f"Delimiter mismatch: {path}"
            i += 1
        assert not quote, f"Unclosed single-line string: {path}"
    assert not stack, f"Unclosed delimiters: {path}"


def check_resources(files: list[Path]) -> int:
    references = 0
    deferred = {"addons/gut/test.gd"}
    for path in files:
        source = path.read_text(encoding="utf-8")
        for resource in re.findall(r'res://([^"\'\s]+)', source):
            references += 1
            assert resource in deferred or (PROJECT / resource).is_file(), f"Missing resource: {resource}"
        if path.suffix == ".tscn":
            ids = set(re.findall(r'\[ext_resource[^\n]* id="([^"]+)"', source))
            used = set(re.findall(r'ExtResource\("([^"]+)"\)', source))
            assert used <= ids, f"Missing ExtResource ID: {path}"
    return references


def check_config(path: Path) -> None:
    source = path.read_text(encoding="utf-8")
    parser = configparser.ConfigParser(interpolation=None, strict=True)
    parser.optionxform = str
    parser.read_string("[__preamble__]\n" + source)
    check_delimiters(path, source)


def main() -> None:
    import yaml  # Existing local module only; no installation or downloads.

    files = sorted(PROJECT.rglob("*.gd")) + sorted(PROJECT.rglob("*.gdshader"))
    scenes = sorted(PROJECT.rglob("*.tscn"))
    configs = [PROJECT / "project.godot", PROJECT / "export_presets.cfg"]
    for path in files:
        source = path.read_text(encoding="utf-8")
        check_delimiters(path, source)
        assert all(line.rstrip() == line for line in source.splitlines()), f"Trailing whitespace: {path}"
        if path.suffix == ".gd":
            assert not any(re.match(r"^ +\S", line) for line in source.splitlines()), f"Space indentation: {path}"
    for path in scenes + configs:
        check_config(path)
    references = check_resources(files + scenes + configs)
    # SafeLoader parses syntax; BaseLoader avoids YAML 1.1 interpreting 'on' as True.
    text = WORKFLOW.read_text(encoding="utf-8")
    yaml.safe_load(text)
    workflow = yaml.load(text, Loader=yaml.BaseLoader)
    events = workflow["on"]
    assert events["push"]["branches"] == ["s2/perf-spike-20261007"]
    for event in ("push", "pull_request"):
        assert events[event]["paths"] == ["s2/**", ".github/workflows/s2-android.yml"]
    job = workflow["jobs"]["test-and-apk"]
    assert job["env"]["GODOT_VERSION"] == "4.7.2"
    assert job["env"]["GUT_VERSION"] == "9.3.0"
    assert workflow["permissions"] == {"contents": "read"}
    project = configs[0].read_text(encoding="utf-8")
    assert 'renderer/rendering_method="mobile"' in project
    assert 'renderer/rendering_method.mobile="mobile"' in project
    assert "window/handheld/orientation=0" in project
    assert 'platform="Android"' in configs[1].read_text(encoding="utf-8")
    assert 'export_templates/${GODOT_VERSION}.stable' in text
    assert "--export-debug Android" in text and "keytool -genkeypair" in text
    assert 'godotengine/godot-builds/releases/download/${release}' in text
    assert "4.8" not in project + text
    all_files = sorted(path for path in PROJECT.rglob("*") if path.is_file())
    assert not any(path.suffix in {".keystore", ".jks", ".apk"} for path in all_files)
    assert not (PROJECT / "addons/gut").exists()
    OUT.mkdir(parents=True, exist_ok=True)
    hashes = {}
    for path in all_files + [WORKFLOW]:
        if OUT in path.parents or path.name in {"WORKER_RESULT.md", "verification-output.txt"}:
            continue
        hashes[path.relative_to(ROOT).as_posix()] = hashlib.sha256(path.read_bytes()).hexdigest()
    bash_scripts = []
    for index, step in enumerate(job["steps"]):
        if "run" in step:
            script = OUT / f"ci-step-{index:02d}.bash"
            script.write_text(step["run"], encoding="utf-8", newline="\n")
            bash_scripts.append(script.relative_to(ROOT).as_posix())
    report = {
        "status": "pass_structural_only",
        "gdscript_files": sum(path.suffix == ".gd" for path in files),
        "shader_files": sum(path.suffix == ".gdshader" for path in files),
        "scene_files": len(scenes),
        "resource_references_checked": references,
        "yaml_parse": "pass (PyYAML SafeLoader + BaseLoader)",
        "scope": "Delimiter/INI structure/references/required settings; not full language syntax",
        "godot_parse": "not_run: Godot absent; downloads/install not authorized",
        "gut_tests": "not_run: Godot and GUT absent",
        "android_export": "not_run: engine/templates/Android toolchain not installed for this task",
        "render_and_s22": "not_run: no authorized runtime or device access",
        "bash_scripts": bash_scripts,
        "sha256": hashes,
    }
    report_path = OUT / "static-checks.json"
    report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"PASS structural: {report['gdscript_files']} GDScript, {len(scenes)} scenes, {references} resource references")
    print("PASS YAML parse: PyYAML SafeLoader + BaseLoader; version, triggers and paths checked")
    print(f"SHA256 manifest: {len(hashes)} files; {report_path.relative_to(ROOT).as_posix()}")
    print("NOT_RUN Godot parse / GUT / APK export / render / S22")


if __name__ == "__main__":
    main()
