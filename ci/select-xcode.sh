#!/usr/bin/env bash
# Selects the newest installed stable Xcode 26 or later: App Store Connect only accepts builds made with the iOS 26 SDK+.
set -euo pipefail
echo "installed:"; ls -d /Applications/Xcode*.app || true
best=$(ls -d /Applications/Xcode_*.app 2>/dev/null | grep -vi beta \
  | sed -E 's#^.*/Xcode_([0-9][0-9.]*)\.app$#\1 &#' | grep -E '^[0-9]' \
  | awk '$1+0 >= 26' | sort -V | tail -1 | cut -d' ' -f2- || true)
if [ -z "$best" ]; then echo "no stable Xcode 26+ on this runner image"; exit 1; fi
sudo xcode-select -s "$best/Contents/Developer"
echo "selected $best"
xcodebuild -version
