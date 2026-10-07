"""Read-only Git/hash/scope audit; report writes stay in s2/verification."""
import hashlib
import json
import subprocess
from pathlib import Path

root = Path(__file__).resolve().parents[2]
out = root / "s2/verification"
git = r"C:\Program Files\Git\cmd\git.exe"
report_path = out / "delivery-checks.json"
report_path.touch(exist_ok=True)


def read_git(*args):
    result = subprocess.run([git, *args], cwd=root, capture_output=True, check=True)
    return result.stdout.decode("utf-8")


def allowed(path):
    return path.startswith("s2/") or path == ".github/workflows/s2-android.yml"


branch = read_git("branch", "--show-current").strip()
assert branch == "s2/perf-spike-20261007", branch
raw = read_git("status", "--porcelain=v1", "-z", "--untracked-files=all")
entries = [entry for entry in raw.split("\0") if entry]
changes = []
for entry in entries:
    assert entry[:2] == "??", f"Unexpected staged/tracked change: {entry}"
    name = entry[3:]
    assert allowed(name), f"Outside allowlist: {name}"
    changes.append(name)
assert not read_git("diff", "--name-only", "HEAD").strip(), "Tracked files changed"
assert not read_git("diff", "--cached", "--name-only").strip(), "Unexpected staging"
read_git("diff", "--check")
manifest = json.loads((out / "static-checks.json").read_text(encoding="utf-8"))
for name, expected in manifest["sha256"].items():
    assert hashlib.sha256((root / name).read_bytes()).hexdigest() == expected, name
assert len(manifest["sha256"]) == 25
for name in changes:
    source = (root / name).read_text(encoding="utf-8-sig")
    if not name.startswith("s2/verification/") and name != "s2/verification-output.txt":
        assert all(line.rstrip() == line for line in source.splitlines()), f"Trailing whitespace: {name}"
result = (root / "s2/WORKER_RESULT.md").read_text(encoding="utf-8")
assert "작성 중" not in result
assert result.count("## 다음 단계 (정확히 하나)") == 1
required = ["s2/project.godot", "s2/export_presets.cfg", "s2/README.md", "s2/PERF_CHECKLIST.md", "s2/WORKER_RESULT.md", ".github/workflows/s2-android.yml"]
assert all((root / name).is_file() and (root / name).stat().st_size > 0 for name in required)
report = {
    "status": "pass",
    "branch": branch,
    "allowlist": ["s2/**", ".github/workflows/s2-android.yml"],
    "tracked_changes": 0,
    "staged_changes": 0,
    "git_diff_check": "pass: exit 0, no output",
    "all_new_text_files_utf8": "pass",
    "source_and_document_whitespace": "pass",
    "source_sha256_matches": len(manifest["sha256"]),
    "baseline": "Initial git status was clean; no commit/push/PR performed",
    "files": sorted(changes),
}
report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print(f"PASS allowlist: {len(changes)} new files, no tracked/staged changes")
print(f"PASS branch: {branch}")
print("PASS git diff --check: exit 0, no output")
print("PASS SHA256: 25 source/config/document files match static manifest")
print("PASS delivery: required files exist, text whitespace checked, one next step")
