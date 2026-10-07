set -euo pipefail
"$GODOT_BIN" --headless --path s2 --editor --quit 2>&1 | tee s2/build/import.log
python3 - <<'PY'
import pathlib, re
log = pathlib.Path('s2/build/import.log').read_text()
if re.search(r'(?m)^(?:SCRIPT ERROR:|ERROR:)|Parse Error:', log):
    raise SystemExit('Godot import reported an error; inspect import.log')
PY
