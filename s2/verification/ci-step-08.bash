set -euo pipefail
key="$RUNNER_TEMP/s2-debug.keystore"
password="$(openssl rand -hex 16)"
echo "::add-mask::$password"
keytool -genkeypair -keystore "$key" -storepass "$password" -keypass "$password" \
  -alias androiddebugkey -dname "CN=Android Debug,O=Android,C=US" \
  -keyalg RSA -keysize 2048 -validity 30 -storetype JKS -noprompt
echo "GODOT_ANDROID_KEYSTORE_DEBUG_PATH=$key" >> "$GITHUB_ENV"
echo "GODOT_ANDROID_KEYSTORE_DEBUG_USER=androiddebugkey" >> "$GITHUB_ENV"
echo "GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD=$password" >> "$GITHUB_ENV"
mkdir -p "$HOME/.config/godot"
cat > "$HOME/.config/godot/editor_settings-4.tres" <<EOF
[gd_resource type="EditorSettings" format=3]

[resource]
export/android/android_sdk_path = "$ANDROID_HOME"
export/android/java_sdk_path = "$JAVA_HOME"
EOF
