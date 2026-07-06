# AutoPilot iOS

iOS platform runner for the AutoPilot declarative GUI test framework.

Runs the same JSON plan format used by [`autopilot-macos`](https://github.com/jschwefel-CBB/autopilot-macos) and [`autopilot-android`](https://github.com/jschwefel-CBB/autopilot-android). Plans are human-readable JSON, but designed to be authored by AI agents — connect an agent to the AutoPilot MCP server, describe what you want tested, and it produces a ready-to-run plan.

## What's here

```
autopilot-ios/
  TestHostApp/             ← UIKit app exposing the full test surface
  TestHostAppSwiftUI/      ← SwiftUI equivalent of the same surface
  TestHostAppUITests/
    PlanModel.swift        ← data classes for the JSON plan
    AutoPilotRunner.swift  ← step executor (XCUITest)
    AutoPilotRunnerTests.swift  ← XCTestCase entry point
    test-all-capabilities.json  ← unified 78-step plan
  project.yml              ← XcodeGen project definition
```

## Prerequisites

- Xcode 16+ (CI builds with Xcode 16)
- XcodeGen: `brew install xcodegen`

## Setup

```bash
git clone https://github.com/jschwefel-CBB/autopilot-ios.git
cd autopilot-ios
xcodegen generate
open TestHostApp.xcodeproj
```

## Running the tests

1. Select the `TestHostApp` scheme in Xcode
2. Choose an iOS Simulator (iOS 16+)
3. Run via Product → Test (⌘U)

Or from the command line:

```bash
xcodebuild test \
  -project TestHostApp.xcodeproj \
  -scheme TestHostApp \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```

## Run on a physical device (USB or wireless)

The runner is device-agnostic — it drives whatever device `xcodebuild -destination`
points at — so a real iPhone works with the same test. `scripts/run-on-device.sh`
wraps team-id + device-UDID resolution and the run.

### Prerequisite: an Apple Developer team

On-device XCUITest **must be code-signed** (the simulator needs none). Supply an
Apple team id one of two ways:

```bash
export DEVELOPMENT_TEAM=XXXXXXXXXX
# …or:  cp Local.xcconfig.example Local.xcconfig   (then edit it — it is git-ignored)
```

Find the id in **Xcode → Settings → Accounts → your team (10 characters)**. A free
**personal** Apple team works for on-device testing; its provisioning profile lasts
~7 days (re-running the script refreshes it via `-allowProvisioningUpdates`). Never
commit a real team id — `project.yml` uses `${DEVELOPMENT_TEAM}` and expands it at
build time from the environment.

### Over USB

Connect the iPhone, **Trust This Computer** on the phone, and enable **Settings →
Privacy & Security → Developer Mode** (iOS 16+). First connection: open **Xcode →
Window → Devices & Simulators** once so Xcode prepares the device (mounts the
Developer Disk Image), and trust the development cert under **Settings → General →
VPN & Device Management**. Then:

```bash
export DEVELOPMENT_TEAM=XXXXXXXXXX
bash scripts/run-on-device.sh                 # the sole connected iPhone
bash scripts/run-on-device.sh --udid 00008120-000A1B2C3D4E5F6G
```

### Wireless

Pair once over USB, then in **Xcode → Window → Devices & Simulators** tick **Connect
via network** for the device. Unplug; the same `--udid` now resolves over Wi-Fi
(phone and Mac on the same network). Selection is explicit-optional: with one device
paired, no `--udid` is needed.

The script prints `Using device UDID: …` so you can confirm which device ran.
Expected result on a real device matches the simulator: **75 PASS + 3 SKIP** (the 3
visual actions have no pixel access via XCUITest).

## Results

The unified 78-step plan achieves **75 PASS + 3 SKIP** on iOS. The 3 skipped steps require pixel-level screen capture not available via XCUITest.

| Action | Status | Reason |
|---|---|---|
| `assertPixel` | SKIP | Pixel-level screen access not available via XCUITest |
| `assertRegion` | SKIP | Same |
| `snapshot` | SKIP | Same |

All other actions pass.

## Core dependency

This runner implements the AutoPilot plan format defined by [`autopilot-core`](https://github.com/jschwefel-CBB/autopilot-core). The plan model mirrors the core schema. Future versions will consume `autopilot-core` directly as a Swift package dependency.

## Cross-platform

The same JSON plan format runs across platforms:

| Platform | Repo | Result |
|---|---|---|
| macOS | [`autopilot-macos`](https://github.com/jschwefel-CBB/autopilot-macos) | 78 PASS (supports the 3 visual steps) |
| iOS | this repo | 75 PASS + 3 SKIP |
| Android | [`autopilot-android`](https://github.com/jschwefel-CBB/autopilot-android) | 75 PASS + 3 SKIP |

## License

MIT
