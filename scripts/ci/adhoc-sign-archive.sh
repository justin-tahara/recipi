#!/usr/bin/env bash
# Ad-hoc signs an archive built with CODE_SIGNING_ALLOWED=NO, so `xcodebuild -exportArchive`
# can re-sign it with the team's cloud-managed distribution certificate.
#
# Why: CI archives without signing so the runner needs no certificate, private key or
# keychain. The export takes each binary's entitlements from its signature in the archive,
# and an unsigned binary has none, so without this step the exported app silently loses
# its App Group and iCloud container, and SwiftData stops at launch. Ad-hoc signing needs
# no identity: it only records the entitlements for the export to carry over.
#
# The entitlements files hold build settings like $(RECIPI_APP_GROUP_ID); they're resolved
# from the Release configuration of each target, the values the archive was built with.
#
# Every target with CODE_SIGN_ENTITLEMENTS must be listed in TARGETS below. A target the
# script doesn't know, or a listed bundle missing from the archive, fails the run instead
# of exporting without its entitlements.
#
# Usage: scripts/ci/adhoc-sign-archive.sh path/to/Recipi.xcarchive
set -euo pipefail

archive="${1:?usage: $0 path/to/Recipi.xcarchive}"
root="$(cd "$(dirname "$0")/../.." && pwd)"
project="${root}/Recipi.xcodeproj"
app="${archive}/Products/Applications/Recipi.app"

# bundle (relative to the archive's app) | Xcode target | entitlements file (relative to the repo) | keys that must survive
TARGETS=(
  "PlugIns/RecipiShare.appex|RecipiShare|RecipiShare/RecipiShare.entitlements|com.apple.security.application-groups com.apple.developer.icloud-container-identifiers"
  ".|Recipi|Recipi/Recipi.entitlements|com.apple.security.application-groups com.apple.developer.icloud-container-identifiers aps-environment"
)

[ -d "${app}" ] || {
  echo "no app at ${app}" >&2
  exit 1
}

# The project's entitlements files must be exactly the ones listed above.
known="$(for t in "${TARGETS[@]}"; do IFS='|' read -r _ _ file _ <<<"${t}"; echo "${file}"; done | sort -u)"
declared="$(grep -E 'CODE_SIGN_ENTITLEMENTS = ' "${project}/project.pbxproj" \
  | sed -E 's/.*CODE_SIGN_ENTITLEMENTS = "?([^";]*)"?;.*/\1/' | sort -u)"
if [ "${known}" != "${declared}" ]; then
  echo "CODE_SIGN_ENTITLEMENTS in the project don't match scripts/ci/adhoc-sign-archive.sh; update its TARGETS" >&2
  echo "project: ${declared//$'\n'/, }" >&2
  echo "script:  ${known//$'\n'/, }" >&2
  exit 1
fi

# Every extension in the archive must be one we sign with its entitlements.
while IFS= read -r -d '' appex; do
  rel="PlugIns/$(basename "${appex}")"
  listed=no
  for t in "${TARGETS[@]}"; do [[ "${t}" == "${rel}|"* ]] && listed=yes; done
  [ "${listed}" = yes ] || {
    echo "${rel} isn't in scripts/ci/adhoc-sign-archive.sh's TARGETS" >&2
    exit 1
  }
done < <(find "${app}/PlugIns" -mindepth 1 -maxdepth 1 -name '*.appex' -print0 2>/dev/null)

work="$(mktemp -d)"
trap 'rm -rf "${work}"' EXIT

# Writes the target's entitlements with every $(SETTING) replaced by its Release value.
resolve_entitlements() {
  local target="$1" file="$2" out="$3"
  xcodebuild -project "${project}" -target "${target}" -configuration Release \
    -showBuildSettings -json 2>/dev/null >"${work}/${target}-settings.json"
  python3 -I - "${root}/${file}" "${work}/${target}-settings.json" "${out}" <<'PY'
import json, re, sys
source, settings, out = sys.argv[1:]
values = json.load(open(settings))[0]["buildSettings"]
text = open(source).read()
missing = sorted({name for name in re.findall(r"\$\((\w+)\)", text) if not values.get(name)})
if missing:
    sys.exit(f"{source}: no Release value for {', '.join(missing)}")
open(out, "w").write(re.sub(r"\$\((\w+)\)", lambda m: values[m.group(1)], text))
PY
}

# Inside out: frameworks first, then each extension, then the app.
while IFS= read -r -d '' bundle; do
  codesign --force --sign - "${bundle}"
done < <(find "${app}/Frameworks" -mindepth 1 -maxdepth 1 \( -name '*.framework' -o -name '*.dylib' \) -print0 2>/dev/null)

for target in "${TARGETS[@]}"; do
  IFS='|' read -r rel xcode_target file keys <<<"${target}"
  bundle="${app}"
  [ "${rel}" = "." ] || bundle="${app}/${rel}"
  [ -d "${bundle}" ] || {
    echo "${rel} is missing from the archive" >&2
    exit 1
  }
  entitlements="${work}/${xcode_target}.entitlements"
  resolve_entitlements "${xcode_target}" "${file}" "${entitlements}"
  codesign --force --sign - --entitlements "${entitlements}" --generate-entitlement-der "${bundle}"

  # Prove the entitlements made it, resolved, without printing anything else.
  signed="$(codesign -d --entitlements - --xml "${bundle}" 2>/dev/null)"
  for key in ${keys}; do
    [[ "${signed}" == *"${key}"* ]] || {
      echo "${key} missing from $(basename "${bundle}") after ad-hoc signing" >&2
      exit 1
    }
  done
  [[ "${signed}" != *"\$("* ]] || {
    echo "$(basename "${bundle}") was signed with an unresolved build setting" >&2
    exit 1
  }
  echo "ad-hoc signed $(basename "${bundle}") with $(basename "${file}")"
done
