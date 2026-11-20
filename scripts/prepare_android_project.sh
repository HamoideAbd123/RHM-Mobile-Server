#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
MOBILE_DIR="${REPO_ROOT}/mobile"
ANDROID_PROJECT="${MOBILE_DIR}/build/rhm_mobile"

command -v flutter >/dev/null 2>&1 || {
  echo "Flutter is required. Install Flutter 3.47+ and retry." >&2
  exit 1
}
command -v python3 >/dev/null 2>&1 || {
  echo "Python 3 is required to prepare the Android manifest." >&2
  exit 1
}

if [[ -e "${ANDROID_PROJECT}" ]]; then
  echo "Refusing to overwrite generated directory: ${ANDROID_PROJECT}" >&2
  echo "Move or remove that generated directory yourself, then rerun this script." >&2
  exit 1
fi

mkdir -p "$(dirname -- "${ANDROID_PROJECT}")"
flutter create --platforms=android --org org.rhm --project-name rhm_mobile "${ANDROID_PROJECT}"

cp "${MOBILE_DIR}/pubspec.yaml" "${ANDROID_PROJECT}/pubspec.yaml"
cp "${MOBILE_DIR}/analysis_options.yaml" "${ANDROID_PROJECT}/analysis_options.yaml"
mkdir -p "${ANDROID_PROJECT}/lib" "${ANDROID_PROJECT}/test"
cp -a "${MOBILE_DIR}/lib/." "${ANDROID_PROJECT}/lib/"
rm -f "${ANDROID_PROJECT}/test/widget_test.dart"
cp -a "${MOBILE_DIR}/test/." "${ANDROID_PROJECT}/test/"

ANDROID_APP="${ANDROID_PROJECT}/android/app"
mkdir -p "${ANDROID_APP}/src/main/res/xml"
cp "${MOBILE_DIR}/android/AndroidManifest.xml.template" "${ANDROID_APP}/src/main/AndroidManifest.xml"
cp "${MOBILE_DIR}/android/network_security_config.xml.template" "${ANDROID_APP}/src/main/res/xml/network_security_config.xml"
cp "${MOBILE_DIR}/android/app-build.gradle.kts.template" "${ANDROID_APP}/build.gradle.kts"

python3 - "${ANDROID_APP}/src/main/AndroidManifest.xml" <<'PY'
from pathlib import Path
import sys

manifest_path = Path(sys.argv[1])
text = manifest_path.read_text(encoding="utf-8")
permission = '    <uses-permission android:name="android.permission.REQUEST_INSTALL_PACKAGES" />\n'
if "android.permission.REQUEST_INSTALL_PACKAGES" not in text:
    anchor = '    <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />\n'
    if anchor not in text:
        raise SystemExit("Could not locate the permission insertion point in AndroidManifest.xml")
    text = text.replace(anchor, anchor + permission, 1)

application = '<application\n'
replacement = '<application\n        android:networkSecurityConfig="@xml/network_security_config"\n'
if 'android:networkSecurityConfig=' not in text:
    if application not in text:
        raise SystemExit("Could not locate the application element in AndroidManifest.xml")
    text = text.replace(application, replacement, 1)

required = (
    'android:allowBackup="false"',
    'android:fullBackupContent="false"',
    'android:usesCleartextTraffic="false"',
    'android:networkSecurityConfig="@xml/network_security_config"',
    'android.permission.REQUEST_INSTALL_PACKAGES',
)
missing = [item for item in required if item not in text]
if missing:
    raise SystemExit(f"Android manifest is missing required security settings: {missing}")
manifest_path.write_text(text, encoding="utf-8")
PY

echo "Android host project prepared at: ${ANDROID_PROJECT}"
