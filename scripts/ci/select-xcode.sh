#!/usr/bin/env bash
# Selects the newest released Xcode on a GitHub-hosted runner rather than the
# image's default, so CI tests with the toolchain TestFlight builds ship with
# (App Store Connect only takes builds from the current SDK).
#
# Usage: scripts/ci/select-xcode.sh
set -euo pipefail

xcode_app="$(printf '%s\n' /Applications/Xcode_*.app | grep -vi beta | sort -V | tail -1)"
[ -d "${xcode_app}" ] || {
  echo "no released Xcode in /Applications" >&2
  exit 1
}
echo "Selecting ${xcode_app}"
sudo xcode-select -s "${xcode_app}"
xcodebuild -version
