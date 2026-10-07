set -euo pipefail
release="${GODOT_VERSION}-stable"
base="https://github.com/godotengine/godot-builds/releases/download/${release}"
engine="Godot_v${release}_linux.x86_64.zip"
templates="Godot_v${release}_export_templates.tpz"
mkdir -p "$RUNNER_TEMP/godot-download" s2/build
cd "$RUNNER_TEMP/godot-download"
curl --fail --location --retry 3 "$base/$engine" -o "$engine"
curl --fail --location --retry 3 "$base/$templates" -o "$templates"
curl --fail --location --retry 3 "$base/SHA512-SUMS.txt" -o SHA512-SUMS.txt
python3 - "$engine" "$templates" <<'PY'
import hashlib, pathlib, sys
sums = {}
for line in pathlib.Path('SHA512-SUMS.txt').read_text().splitlines():
    fields = line.split()
    if len(fields) == 2:
        sums[fields[1].lstrip('*')] = fields[0]
for name in sys.argv[1:]:
    actual = hashlib.sha512(pathlib.Path(name).read_bytes()).hexdigest()
    if sums.get(name) != actual:
        raise SystemExit(f'Checksum missing or mismatched: {name}')
    print(f'SHA512 verified: {name}')
PY
unzip -q "$engine" -d engine
chmod +x "engine/Godot_v${release}_linux.x86_64"
echo "$PWD/engine" >> "$GITHUB_PATH"
echo "GODOT_BIN=$PWD/engine/Godot_v${release}_linux.x86_64" >> "$GITHUB_ENV"
"$PWD/engine/Godot_v${release}_linux.x86_64" --headless --version | tee "$GITHUB_WORKSPACE/s2/build/godot-version.txt"
test "$(cut -d. -f1-4 "$GITHUB_WORKSPACE/s2/build/godot-version.txt")" = "${GODOT_VERSION}.stable"
unzip -q "$templates" -d unpacked
template_dir="$HOME/.local/share/godot/export_templates/${GODOT_VERSION}.stable"
mkdir -p "$template_dir"
cp -a unpacked/templates/. "$template_dir/"
