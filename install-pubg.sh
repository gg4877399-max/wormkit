#!/bin/bash
set +e
echo "=== Try official PUBG link ==="
curl -L -A "Mozilla/5.0 (Linux; Android 10; Pixel 7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Mobile Safari/537.36" "https://pubgmobile.live/apk" -o pubg.bin --max-time 900
ls -lh pubg.bin
file pubg.bin
if ! file pubg.bin | grep -qi "zip"; then
  echo "Official link did not give an APK, trying Uptodown"
  curl -L -A "Mozilla/5.0 (Linux; Android 10; Pixel 7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Mobile Safari/537.36" "https://pubg-mobile.en.uptodown.com/android/download" -o pubg.bin --max-time 900
  ls -lh pubg.bin
  file pubg.bin
fi
echo "=== Install ==="
INSTALLED=0
if file pubg.bin | grep -qi "zip"; then
  mkdir -p pubg_pkg
  unzip -o pubg.bin -d pubg_pkg || true
  ls pubg_pkg/ || true
  INNER=$(ls pubg_pkg/*.apk 2>/dev/null | head -1)
  if [ -n "$INNER" ]; then
    echo "XAPK inner APK: $INNER"
    adb install -r "$INNER" || adb install "$INNER" || true
    if [ -d pubg_pkg/Android/obb ]; then adb push pubg_pkg/Android/obb /sdcard/Android/ || true; fi
  else
    echo "Plain APK file, installing directly"
    adb install -r pubg.bin || adb install pubg.bin || true
  fi
else
  echo "Download did not produce a valid APK, aborting install"
fi
echo "=== Verify install ==="
if adb shell pm list packages | grep -q "com.tencent.ig"; then
  echo "PUBG INSTALLED"
  INSTALLED=1
else
  echo "PUBG NOT INSTALLED"
fi
echo "=== Launch PUBG ==="
adb shell monkey -p com.tencent.ig -c android.intent.category.LAUNCHER 1 || true
sleep 30
echo "=== Check process ==="
adb shell pidof com.tencent.ig || adb shell ps | grep tencent || true
adb shell dumpsys window windows | grep -i mCurrentFocus | head -5 || true
if [ "$INSTALLED" = "1" ]; then
  echo "RESULT: SUCCESS"
  exit 0
else
  echo "RESULT: FAILED - PUBG not installed"
  exit 1
fi
