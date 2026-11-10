#!/usr/bin/env bash
# Prints the UDID of an available iPhone simulator on the newest iOS runtime
# the selected SDK can run. Device names change with each Xcode, so CI picks
# one instead of naming it. An optional argument narrows it to names that
# contain that text, e.g. "Pro Max" for the 6.9-inch size App Store
# screenshots need.
#
# Usage: udid="$(scripts/ci/pick-simulator.sh [name-contains])"
set -euo pipefail

sdk_version="$(xcrun --sdk iphonesimulator --show-sdk-version)"
xcrun simctl list devices available -j | python3 -I -c '
import json, re, sys
sdk = tuple(int(part) for part in sys.argv[1].split("."))
wanted = sys.argv[2]
candidates = []
for runtime, devices in json.load(sys.stdin)["devices"].items():
    match = re.search(r"iOS-(\d+)-(\d+)", runtime)
    if not match:
        continue
    version = (int(match.group(1)), int(match.group(2)))
    if version > sdk:
        continue
    for device in devices:
        if device["name"].startswith("iPhone") and wanted in device["name"]:
            candidates.append((version, -len(device["name"]), device["name"], device["udid"]))
if not candidates:
    sys.exit("No available iPhone simulator" + (" named *" + wanted + "*" if wanted else "") + " for iOS " + sys.argv[1])
version, _, name, udid = max(candidates)
print(f"Using {name} (iOS {version[0]}.{version[1]})", file=sys.stderr)
print(udid)
' "${sdk_version}" "${1:-}"
