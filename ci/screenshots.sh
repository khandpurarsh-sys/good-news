#!/bin/bash
# Renders app + widget preview screenshots on a simulator using -demo data.
set -e
mkdir -p previews
DEVICE=$(xcrun simctl list devices available -j | python3 -c '
import json,sys
d=json.load(sys.stdin)["devices"]
runtimes=sorted(d.keys(), reverse=True)
for rt in runtimes:
    if "iOS" not in rt: continue
    for dev in d[rt]:
        if "iPhone" in dev["name"]:
            print(dev["udid"]); sys.exit(0)
sys.exit(1)')
echo "Using simulator $DEVICE"
xcrun simctl boot "$DEVICE" 2>/dev/null || true
xcrun simctl bootstatus "$DEVICE" -b
APP=$(find build/Build/Products -name 'GoodNews.app' -path '*iphonesimulator*' | head -1)
xcrun simctl install "$DEVICE" "$APP"
shoot() {
  xcrun simctl terminate "$DEVICE" com.arsh.goodnews 2>/dev/null || true
  xcrun simctl ui "$DEVICE" appearance "$1"
  xcrun simctl launch "$DEVICE" com.arsh.goodnews -demo -shot "$2"
  sleep 3
  xcrun simctl io "$DEVICE" screenshot "previews/$3"
}
shoot light app app-light.png
shoot dark app app-dark.png
shoot light widget-small widget-small-light.png
shoot dark widget-small widget-small-dark.png
shoot light widget-medium widget-medium-light.png
shoot dark widget-medium widget-medium-dark.png
shoot light widget-large widget-large-light.png
shoot dark widget-large widget-large-dark.png
xcrun simctl terminate "$DEVICE" com.arsh.goodnews || true
ls -la previews/
