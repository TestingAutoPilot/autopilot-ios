# AutoPilot iOS TestHostApp

Native iOS app exposing a fixed 36-element UI surface for the AutoPilot unified test plan.

## Prerequisites

- Xcode 15+
- XcodeGen (`brew install xcodegen`)

## Setup

```bash
cd autopilot-ios/TestHostApp
xcodegen generate
open TestHostApp.xcodeproj
```

## Targets

| Target | Description |
|--------|-------------|
| `TestHostApp` | UIKit app with all 36 accessibility elements |
| `TestHostAppSwiftUI` | SwiftUI app with the same 36 elements |
| `TestHostAppUITests` | XCUITest runner that reads `test-all-capabilities.json` |

## Running the Tests

1. Select the `TestHostApp` scheme in Xcode
2. Choose an iOS Simulator (iOS 16+)
3. Run the `TestHostAppUITests` target via Product → Test (⌘U)

The runner loads the unified plan from:
- Bundle resource: `test-all-capabilities.json` (copied by build phase)
- Fallback: `/Users/jschwefel/repositories/autopilot/Fixtures/TestHostApp/test-all-capabilities.json`

## Plan JSON Location

The plan lives at:
```
../autopilot/Fixtures/TestHostApp/test-all-capabilities.json
```

The `project.yml` includes a resource reference. After running `xcodegen generate`, add the file to the `TestHostAppUITests` target resources in Xcode if the automatic reference is not picked up.

## Skipped Checks

The following plan actions are not supported by XCUITest and are skipped:
- `assertPixel`
- `assertRegion`
- `snapshot`

All other actions in the unified plan are executed.
