#!/usr/bin/env bash
# Boots an iPhone simulator, installs the built app and takes one screenshot per route.
set -euo pipefail
APP=$(find build/Build/Products/Debug-iphonesimulator -maxdepth 1 -name '*.app' | head -1)
BID=com.pharmjeed.ilmminalkitab
UDID=$(xcrun simctl list devices available -j | python3 -c '
import json,sys
d=json.load(sys.stdin)["devices"]
c=[x for k,v in d.items() if "iOS" in k for x in v if x["name"].startswith("iPhone") and "Pro Max" not in x["name"] and "Plus" not in x["name"]]
print(c[-1]["udid"])')
echo "simulator $UDID"
xcrun simctl boot "$UDID" || true
xcrun simctl bootstatus "$UDID" -b
xcrun simctl ui "$UDID" appearance dark
xcrun simctl status_bar "$UDID" override --time "9:41" --batteryState charged --batteryLevel 100 || true
xcrun simctl install "$UDID" "$APP"
mkdir -p shots
shot () {
  local name=$1; shift
  xcrun simctl terminate "$UDID" "$BID" >/dev/null 2>&1 || true
  xcrun simctl launch "$UDID" "$BID" "$@" >/dev/null
  sleep "${WAIT:-5}"
  xcrun simctl io "$UDID" screenshot "shots/$name.png" >/dev/null
  echo "shot $name"
}
while IFS='|' read -r name args; do
  [ -z "$name" ] && continue
  # shellcheck disable=SC2086
  shot "$name" $args
done < ci/routes.txt
