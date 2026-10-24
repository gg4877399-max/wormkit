#!/bin/bash
# Play Store sign-in + PUBG Mobile install (emulator, GitHub Actions).
# Google credentials come from repo Secrets via step env vars.
# NEVER echo the secret values.
set +e
mkdir -p screenshots

echo "=== Preconditions ==="
if [ -z "$GOOGLE_EMAIL" ]; then echo "ERROR: GOOGLE_EMAIL is empty (check repo Secrets)"; exit 1; fi
if [ -z "$GOOGLE_PASSWORD" ]; then echo "ERROR: GOOGLE_PASSWORD is empty (check repo Secrets)"; exit 1; fi
adb wait-for-device
adb shell pm list packages | grep -i "vending\|gms" || echo "WARNING: Play Store packages not found"
adb shell input keyevent 82 || true

echo "=== Launch Play Store ==="
adb shell monkey -p com.android.vending -c android.intent.category.LAUNCHER 1
sleep 15

tap_text() {
  local needle="$1"
  adb shell uiautomator dump /sdcard/ui.xml >/dev/null 2>&1
  adb pull /sdcard/ui.xml /tmp/ui.xml >/dev/null 2>&1
  local node=$(grep -F "text=\"$needle\"" /tmp/ui.xml | grep 'clickable="true"' | head -1)
  if [ -z "$node" ]; then node=$(grep -F "text=\"$needle\"" /tmp/ui.xml | head -1); fi
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

echo "=== Sign in ==="
if ui_has "Sign in" || ui_has "Sign In"; then
  echo "Sign-in prompt found"
  tap_text "Sign in" || tap_text "Sign In" || true
  sleep 8
fi
for i in 1 2 3 4 5 6; do
  if ui_has "Email or phone"; then break; fi
  sleep 5
done
if ui_has "Email or phone"; then
  tap_text "Email or phone" || true
  sleep 2
  type_text "$GOOGLE_EMAIL"
  sleep 2
  tap_text "Next" || true
  sleep 8
else
  echo "WARNING: email field not found, continuing anyway"
fi
for i in 1 2 3 4 5 6; do
  if ui_has "Enter your password"; then break; fi
  sleep 5
done
if ui_has "Enter your password"; then
  tap_text "Enter your password" || true
  sleep 2
  type_text "$GOOGLE_PASSWORD"
  sleep 2
  tap_text "Next" || true
  sleep 10
else
  echo "WARNING: password field not found, continuing anyway"
fi
echo "=== Verification wait (up to 5 min) ==="
for i in $(seq 1 30); do
  if ui_has "Verify"; then
    echo "Verification screen still present ($i/30), waiting..."
    sleep 10
  else
    break
  fi
done
if ui_has "Verify"; then
  echo "RESULT: VERIFICATION_REQUIRED - Google is asking for verification on another device"
  adb exec-out screencap -p > screenshots/verification.png || true
  exit 2
fi
tap_text "I agree" || true
sleep 3
tap_text "Accept" || true
sleep 3
tap_text "Skip" || true
sleep 3
tap_text "No thanks" || true
sleep 5

echo "=== Open PUBG page ==="
adb shell am start -a android.intent.action.VIEW -d "market://details?id=com.tencent.ig"
sleep 10
tap_text "Install" || true
echo "=== Wait for install (up to 30 min) ==="
INSTALLED=0
for i in $(seq 1 60); do
  if adb shell pm list packages | grep -q "com.tencent.ig"; then INSTALLED=1; break; fi
  sleep 30
done
echo "=== Verify + launch ==="
if [ "$INSTALLED" = "1" ]; then echo "PUBG INSTALLED"; else echo "PUBG NOT INSTALLED"; fi
adb shell monkey -p com.tencent.ig -c android.intent.category.LAUNCHER 1 || true
sleep 20
adb shell pidof com.tencent.ig || true
adb shell dumpsys window windows | grep -i mCurrentFocus | head -3 || true
adb exec-out screencap -p > screenshots/pubg-launch.png || true
adb shell uiautomator dump /sdcard/ui.xml >/dev/null 2>&1
adb pull /sdcard/ui.xml screenshots/final-ui.xml >/dev/null 2>&1 || true
if [ "$INSTALLED" = "1" ]; then echo "RESULT: SUCCESS"; exit 0; else echo "RESULT: FAILED - PUBG not installed"; exit 1; fi
