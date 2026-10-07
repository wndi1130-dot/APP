set -euo pipefail
curl --fail --location --retry 3 "https://github.com/bitwes/Gut/archive/refs/tags/v${GUT_VERSION}.zip" -o "$RUNNER_TEMP/gut.zip"
unzip -q "$RUNNER_TEMP/gut.zip" -d "$RUNNER_TEMP/gut"
mkdir -p s2/addons
gut_root="$RUNNER_TEMP/gut/Gut-${GUT_VERSION}"
cp -a "$gut_root/addons/gut" s2/addons/gut
# Framework stays untracked; GUT ships its license inside addons/gut.
test -s s2/addons/gut/LICENSE.md
# Only the disposable CI checkout enables tests after GUT is present.
python3 -c "from pathlib import Path; Path('s2/tests/.gdignore').unlink()"
