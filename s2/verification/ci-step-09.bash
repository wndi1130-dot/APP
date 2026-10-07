set -euo pipefail
"$GODOT_BIN" --headless --path s2 --export-debug Android build/s2-perf-debug.apk 2>&1 | tee s2/build/export.log
test -s s2/build/s2-perf-debug.apk
"$ANDROID_HOME/build-tools/35.0.0/apksigner" verify --verbose s2/build/s2-perf-debug.apk | tee s2/build/signature.txt
sha256sum s2/build/s2-perf-debug.apk > s2/build/apk.sha256
