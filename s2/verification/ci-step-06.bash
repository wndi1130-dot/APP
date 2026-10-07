set -euo pipefail
"$GODOT_BIN" --headless --path s2 --editor --quit 2>&1 | tee s2/build/import.log
# Parse every project and test script, so one run reports all parse errors.
for script in $(cd s2 && find scripts tests -name '*.gd' | sort); do
  echo "== check $script" | tee -a s2/build/import.log
  "$GODOT_BIN" --headless --path s2 --check-only --script "res://$script" 2>&1 | tee -a s2/build/import.log || true
done
python3 - <<'PY'
import pathlib, re
log = pathlib.Path('s2/build/import.log').read_text()
if re.search(r'(?m)^(?:SCRIPT ERROR:|ERROR:)|Parse Error:', log):
    raise SystemExit('Godot import reported an error; inspect import.log')
PY
