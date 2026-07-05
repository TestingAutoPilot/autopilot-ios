#!/usr/bin/env bash
# Drive the AutoPilot plan on a PHYSICAL iPhone (USB or wireless).
#
# The runner (AutoPilotRunner.swift) is device-agnostic — it holds an
# XCUIApplication and never names a UDID — so choosing WHICH device is driven is
# purely an `xcodebuild -destination 'platform=iOS,id=<UDID>'` concern. This
# wrapper owns that: it resolves the Apple team id (required for on-device
# signing), resolves the target device UDID (explicit or the sole connected
# iPhone), regenerates the project with the team in the environment, and runs.
#
# No Swift change — pure host-side tooling. Same 78-step plan, same expected
# result as the simulator: 75 PASS + 3 SKIP (the 3 visual actions have no pixel
# access via XCUITest).
#
# PREREQUISITE — Apple team id (physical XCUITest MUST be code-signed):
#   export DEVELOPMENT_TEAM=XXXXXXXXXX
#   …or copy Local.xcconfig.example → Local.xcconfig and set it there.
# A free personal Apple team works; its profile lasts ~7 days.
#
# FIRST-RUN, one-time and interactive (cannot be scripted):
#   • Trust the Mac on the iPhone ("Trust This Computer?").
#   • Enable Developer Mode: Settings → Privacy & Security → Developer Mode (iOS 16+).
#   • Let Xcode prepare the device / mount the Developer Disk Image (open
#     Xcode → Window → Devices & Simulators once; a first `xcodebuild` may need
#     one retry after the DDI mounts).
#   • Trust the development cert: Settings → General → VPN & Device Management.
#   • Wireless: after pairing over USB, tick "Connect via network" for the device
#     in Xcode → Devices & Simulators. Thereafter the same --udid resolves over Wi-Fi.
#
# Examples:
#   export DEVELOPMENT_TEAM=XXXXXXXXXX
#   bash scripts/run-on-device.sh                 # the sole connected iPhone
#   bash scripts/run-on-device.sh --udid 00008120-000A1B2C3D4E5F6G
set -euo pipefail
cd "$(dirname "$0")/.."

UDID=""
while [ $# -gt 0 ]; do
  case "$1" in
    --udid) UDID="${2:?--udid needs a value}"; shift 2 ;;
    -h|--help) sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

# --- Resolve the Apple team id (fail fast — the hard prerequisite) ------------
if [ -z "${DEVELOPMENT_TEAM:-}" ] && [ -f Local.xcconfig ]; then
  DEVELOPMENT_TEAM="$(grep -E '^DEVELOPMENT_TEAM' Local.xcconfig | sed 's/.*= *//' | tr -d ' ')"
fi
if [ -z "${DEVELOPMENT_TEAM:-}" ]; then
  echo "No Apple team id. Physical XCUITest requires code-signing." >&2
  echo "Set it with:  export DEVELOPMENT_TEAM=XXXXXXXXXX" >&2
  echo "         or:  cp Local.xcconfig.example Local.xcconfig  (then edit it)" >&2
  echo "Find it in Xcode → Settings → Accounts → your team's 10-char ID." >&2
  exit 1
fi
export DEVELOPMENT_TEAM
echo "==> Using DEVELOPMENT_TEAM: $DEVELOPMENT_TEAM" >&2

# --- Resolve the target device UDID ------------------------------------------
# Prefer `devicectl` (Xcode 15+); its JSON lists connected physical devices.
if [ -z "$UDID" ]; then
  UDID="$( { xcrun devicectl list devices --json-output - 2>/dev/null | python3 -c '
import json, sys
try:
    data = json.load(sys.stdin)
except Exception:
    print(""); sys.exit(0)
devs = data.get("result", {}).get("devices", [])
picked = []
for d in devs:
    conn = (d.get("connectionProperties", {}) or {})
    hw   = (d.get("hardwareProperties", {}) or {})
    state = conn.get("tunnelState") or conn.get("pairingState") or ""
    # iPhones that are paired/connected (USB or network).
    if "iPhone" in (hw.get("deviceType","") + hw.get("productType","") + d.get("deviceProperties",{}).get("name","")):
        udid = hw.get("udid") or d.get("identifier","")
        if udid:
            picked.append(udid)
print("\n".join(picked))
' 2>/dev/null; } || true )"
  # Fallback: parse `xcrun xctrace list devices` text (physical section = a UDID in
  # trailing parens, on an iPhone line, before the "== Simulators" divider). Uses
  # sed for the capture so it works with BSD awk (no gawk 3-arg match()). The
  # trailing `|| true` keeps a no-match `grep` from aborting under set -e/pipefail.
  if [ -z "$UDID" ]; then
    UDID="$( { xcrun xctrace list devices 2>/dev/null \
      | sed -n '1,/^== Simulators/p' \
      | grep iPhone \
      | sed -n 's/.*(\([0-9A-Fa-f][0-9A-Fa-f-]\{20,\}\))[[:space:]]*$/\1/p'; } || true )"
  fi
  COUNT="$(printf '%s\n' "$UDID" | grep -c . || true)"
  if [ "$COUNT" -eq 0 ]; then
    echo "No connected physical iPhone. Pair one in Xcode → Devices & Simulators" >&2
    echo "(USB, or 'Connect via network' after a USB pairing). Inventory:" >&2
    xcrun devicectl list devices 2>/dev/null >&2 || xcrun xctrace list devices >&2
    exit 1
  elif [ "$COUNT" -gt 1 ]; then
    echo "Multiple devices; pass --udid <udid>. Candidates:" >&2
    printf '  %s\n' $UDID >&2
    exit 1
  fi
  UDID="$(printf '%s\n' "$UDID" | head -n1)"
fi
echo "==> Using device UDID: $UDID" >&2

# --- Regenerate the project (team now in env) and run -------------------------
echo "==> Regenerating project with the team in the environment" >&2
xcodegen generate

echo "==> Running the plan on the device" >&2
# xcodebuild refuses to overwrite an existing result bundle — clear a stale one.
rm -rf TestResults.xcresult
xcodebuild test \
  -project TestHostApp.xcodeproj \
  -scheme TestHostApp \
  -destination "platform=iOS,id=$UDID" \
  -allowProvisioningUpdates \
  -resultBundlePath TestResults.xcresult
