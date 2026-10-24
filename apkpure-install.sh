#!/bin/bash
# APKPure route: install the APKPure app, then install PUBG Mobile from inside it.
# No Google sign-in needed. Screenshots + UI dumps are saved for debugging.
set +e
mkdir -p screenshots

echo "=== Download APKPure app APK (try several sources) ==="
APK=""
try_url() {
  echo "--- Trying: $1"
  curl -L -A "Mozilla/5.0 (Linux; Android 10; Pixel 7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Mobile Safari/537.36" "$1" -o apkpure.bin --max-time 180
  ls -lh apkpure.bin || true
  file apkpure.bin || true
  if file apkpure.bin | grep -qi "zip"; then
    echo "GOT VALID APK"
    APK=apkpure.bin
    return 0
  fi
  return 1
}
try_url "https://d.apkpure.com/b/APK/com.apkpure.aegon?version=latest" || try_url "https://apkpure.com/apkpure-app/com.apkpure.aegon/download" || try_url "https://apkpure-app.en.uptodown.com/android/download" || echo "ALL APKPure app download sources failed"

if [ -z "$APK" ]; then
  echo "RESULT: FAILED - could not download APKPure app APK"
  exit 1
fi

echo "=== Install APKPure app ==="
adb wait-for-device
adb install -r apkpure.bin || adb install apkpure.bin || true
adb shell pm list packages | grep -i "apkpure" || echo "WARNING: APKPure package not found after install"

echo "=== Launch APKPure app ==="
adb shell monkey -p com.apkpure.aegon -c android.intent.category.LAUNCHER 1
sleep 15

tap_text() {
  local needle="$1"
  adb shell uiautomator dump /sdcard/ui.xml >/dev/null 2>&1
  adb pull /sdcard/ui.xml /tmp/ui.xml >/dev/null 2>&1
  local node=$(grep -F "text=\"$needle\"" /tmp/ui.xml | grep 'clickable="true"' | head -1)
  if [ -z "$node" ]; then node=$(grep -F "content-desc=\"$needle\"" /tmp/ui.xml | grep 'clickable="true"' | head -1); fi
  if [ -z "$node" ]; then node=$(grep -F "text=\"$needle\"" /tmp/ui.xml | head -1); fi
  if [ -z "$node" ]; then node=$(grep -F "content-desc=\"$needle\"" /tmp/ui.xml | head -1); fi
  if [ -z "$node" ]; then echo "tap_text: '$needle' NOT FOUND"; return 1; fi
  local b=$(echo "$node" | sed -n 's/.*bounds="\[\([0-9]*\),\([0-9]*\)\]\[\([0-9]*\),\([0-9]*\)\]\".*/\1 \2 \3 \4/p')
  set -- $b
  local cx=$(( ($1 + $3) / 2 ))
  local cy=$(( ($2 + $4) / 2 ))
  echo "tap_text: '$needle' -> ($cx,$cy)"
  adb shell input tap $cx $cy
  return 0
}

type_text() {
  local esc=$(printf '%s' "$1" | sed 's/ /%s/g')
  adb shell input text "$esc"
}

ui_has() {
  adb shell uiautomator dump /sdcard/ui.xml >/dev/null 2>&1
  adb pull /sdcard/ui.xml /tmp/ui.xml >/dev/null 2>&1
  grep -q -F "$1" /tmp/ui.xml
}

echo "=== Dismiss onboarding ==="
tap_text "Agree" || true
sleep 2
tap_text "Continue" || true
sleep 2
tap_text "Allow" || true
sleep 2
tap_text "Skip" || true
sleep 3
adb exec-out screencap -p > screenshots/apkpure-home.png || true

echo "=== Search PUBG ==="
tap_text "Search" || tap_text "Search apps" || tap_text "Search APKPure" || true
sleep 3
type_text "PUBG Mobile"
sleep 2
adb shell input keyevent 66
sleep 10
adb exec-out screencap -p > screenshots/apkpure-search.png || true
tap_text "PUBG MOBILE" || tap_text "PUBG Mobile" || true
sleep 10
adb exec-out screencap -p > screenshots/apkpure-details.png || true

echo "=== Tap Download/Install ==="
tap_text "Download" || tap_text "Install" || true
sleep 10

echo "=== Wait for PUBG install (up to 30 min), handling permission dialogs ==="
INSTALLED=0
for i in $(seq 1 60); do
  if adb shell pm list packages | grep -q "com.tencent.ig"; then INSTALLED=1; break; fi
  if ui_has "Allow from this source"; then
    echo "Allowing unknown sources for APKPure"
    tap_text "Allow from this source" || true
    sleep 2
    adb shell input keyevent 4
    sleep 3
  fi
  if ui_has "Do you want to install"; then
    echo "System installer prompt found, tapping Install"
    tap_text "Install" || true
    sleep 3
  fi
  sleep 30
done
echo "=== Verify + launch ==="
if [ "$INSTALLED" = "1" ]; then echo "PUBG INSTALLED"; else echo "PUBG NOT INSTALLED"; fi
tap_text "Open" || tap_text "Done" || true
sleep 2
adb shell monkey -p com.tencent.ig -c android.intent.category.LAUNCHER 1 || true
sleep 20
adb shell pidof com.tencent.ig || true
adb shell dumpsys window windows | grep -i mCurrentFocus | head -3 || true
adb exec-out screencap -p > screenshots/pubg-launch.png || true
adb shell uiautomator dump /sdcard/ui.xml >/dev/null 2>&1
adb pull /sdcard/ui.xml screenshots/final-ui.xml >/dev/null 2>&1 || true
if [ "$INSTALLED" = "1" ]; then echo "RESULT: SUCCESS"; exit 0; else echo "RESULT: FAILED - PUBG not installed"; exit 1; fi
