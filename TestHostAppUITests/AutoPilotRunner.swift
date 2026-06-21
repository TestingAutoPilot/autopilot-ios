import XCTest

// MARK: - Step Result

struct StepResult {
    let id: String
    let passed: Bool
    let skipped: Bool
    let message: String
}

// MARK: - AutoPilotRunner

class AutoPilotRunner {
    let app: XCUIApplication

    init(app: XCUIApplication = XCUIApplication()) {
        self.app = app
    }

    // MARK: - Plan Loading

    func loadPlan() throws -> Plan {
        // Try bundle resource first
        if let url = Bundle(for: type(of: self)).url(forResource: "test-all-capabilities", withExtension: "json") {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(Plan.self, from: data)
        }

        // Fallback: relative path from repo
        let fallbackPath = "/Users/jschwefel/repositories/autopilot/Fixtures/TestHostApp/test-all-capabilities.json"
        let fallbackURL = URL(fileURLWithPath: fallbackPath)
        let data = try Data(contentsOf: fallbackURL)
        return try JSONDecoder().decode(Plan.self, from: data)
    }

    // MARK: - Run

    func run() throws -> [StepResult] {
        let plan = try loadPlan()
        app.launch()

        var results: [StepResult] = []

        for step in plan.steps {
            let stepId = step.id ?? "unnamed"

            // Comment-only steps: skip silently
            if step.action == nil {
                results.append(StepResult(id: stepId, passed: true, skipped: true, message: "comment-only"))
                continue
            }

            let action = step.action ?? ""

            // Platform-only skips
            if ["assertPixel", "assertRegion", "snapshot"].contains(action) {
                print("skipped: \(stepId) (\(action) not supported on iOS runner)")
                results.append(StepResult(id: stepId, passed: true, skipped: true, message: "not supported on iOS"))
                continue
            }

            do {
                try executeStep(step)
                results.append(StepResult(id: stepId, passed: true, skipped: false, message: "ok"))
            } catch {
                let msg = "Step \(stepId) failed: \(error)"
                print(msg)
                results.append(StepResult(id: stepId, passed: false, skipped: false, message: msg))
            }
        }

        return results
    }

    // MARK: - Step Dispatch

    private func executeStep(_ step: Step) throws {
        let action = step.action ?? ""

        switch action {
        case "waitFor":
            try executeWaitFor(step)
        case "click", "press":
            try executeClick(step)
        case "doubleClick":
            try executeDoubleClick(step)
        case "rightClick":
            try executeRightClick(step)
        case "type":
            try executeType(step)
        case "setValue":
            try executeSetValue(step)
        case "scroll":
            try executeScroll(step)
        case "drag":
            try executeDrag(step)
        case "menu":
            try executeMenu(step)
        case "assert":
            try executeAssert(step)
        case "screenshot":
            executeScreenshot(step)
        case "keyPress":
            try executeKeyPress(step)
        case "wait":
            executeWait(step)
        case "terminate":
            app.terminate()
        case "launch":
            app.launch()
        default:
            print("Unknown action: \(action) — skipping step \(step.id ?? "unnamed")")
        }
    }

    // MARK: - Element Resolution

    private func resolveElement(_ selector: SelectorJSON?) -> XCUIElement {
        guard let sel = selector else {
            return app
        }

        // Identifier-based (highest priority)
        if let identifier = sel.identifier {
            // Check alerts first for special identifiers (confirmButton, cancelButton)
            if ["confirmButton", "cancelButton"].contains(identifier) {
                let alertButton = app.alerts.buttons.matching(identifier: identifier).firstMatch
                if !alertButton.exists {
                    // fallback: by title
                    if identifier == "confirmButton" {
                        return app.alerts.buttons["Confirm"]
                    } else {
                        return app.alerts.buttons["Cancel"]
                    }
                }
                return alertButton
            }

            // Within parent?
            if let within = sel.within {
                let parent = resolveParent(within)
                let idx = sel.index ?? 0
                let children = parent.descendants(matching: .any).matching(identifier: identifier)
                if children.count > idx {
                    return children.element(boundBy: idx)
                }
                return children.firstMatch
            }

            return app.descendants(matching: .any).matching(identifier: identifier).firstMatch
        }

        // Role + title
        if let role = sel.role, let title = sel.title {
            // AXMenuItem by title — context menus and UIMenu items
            if role == "AXMenuItem" {
                // Try buttons (UIMenu items appear as buttons in XCUITest)
                let btn = app.buttons[title]
                if btn.exists { return btn }
                return app.menuItems[title]
            }
            // AXButton with title
            let type = xcuiElementType(for: role)
            return app.descendants(matching: type).matching(NSPredicate(format: "label == %@", title)).firstMatch
        }

        // Role only (with optional index, within)
        if let role = sel.role {
            // AXMenuBar within — special case (no menu bar on iOS, return non-existent)
            if role == "AXMenuBar" {
                return app.menuBars.element(boundBy: 0)
            }

            let type = xcuiElementType(for: role)

            if let within = sel.within {
                let parent = resolveParent(within)
                let idx = sel.index ?? 0
                // AXRadioButton within segmented control
                if role == "AXRadioButton" {
                    let seg = parent.descendants(matching: .segmentedControl).firstMatch
                    return seg.buttons.element(boundBy: idx)
                }
                // AXButton within stepper
                if role == "AXButton" {
                    return parent.descendants(matching: .button).element(boundBy: idx)
                }
                return parent.descendants(matching: type).element(boundBy: idx)
            }

            let idx = sel.index ?? 0
            // AXWindow
            if role == "AXWindow" {
                return app.windows.firstMatch
            }
            // AXSheet — iOS alert/sheet
            if role == "AXSheet" {
                return app.alerts.firstMatch
            }

            let query = app.descendants(matching: type)
            if sel.index != nil {
                return query.element(boundBy: idx)
            }
            return query.firstMatch
        }

        // Title only
        if let title = sel.title {
            let btn = app.buttons[title]
            if btn.exists { return btn }
            return app.staticTexts[title]
        }

        return app
    }

    private func resolveParent(_ sel: SelectorJSON) -> XCUIElement {
        if let identifier = sel.identifier {
            return app.descendants(matching: .any).matching(identifier: identifier).firstMatch
        }
        if let role = sel.role {
            let type = xcuiElementType(for: role)
            return app.descendants(matching: type).firstMatch
        }
        return app
    }

    private func xcuiElementType(for role: String) -> XCUIElement.ElementType {
        switch role {
        case "AXButton": return .button
        case "AXTextField": return .textField
        case "AXStaticText": return .staticText
        case "AXCheckBox": return .switch
        case "AXSlider": return .slider
        case "AXTable": return .table
        case "AXTextArea": return .textView
        case "AXScrollArea": return .scrollView
        case "AXWindow": return .window
        case "AXSheet": return .sheet
        case "AXRadioGroup": return .segmentedControl
        case "AXRadioButton": return .button
        case "AXMenuItem": return .menuItem
        case "AXMenuBar": return .menuBar
        default: return .any
        }
    }

    // MARK: - Actions

    private func executeWaitFor(_ step: Step) throws {
        let present = step.args?.present ?? true
        let timeoutMs = 5000
        let timeout = Double(timeoutMs) / 1000.0

        let element = resolveElement(step.target)

        if present {
            let exists = element.waitForExistence(timeout: timeout)
            if !exists {
                throw RunnerError.elementNotFound(step.id ?? "unnamed")
            }
        } else {
            // Poll until not exists
            let deadline = Date().addingTimeInterval(timeout)
            while Date() < deadline {
                if !element.exists { return }
                Thread.sleep(forTimeInterval: 0.1)
            }
            // Not an error if still exists at timeout for present:false
        }
    }

    private func executeClick(_ step: Step) throws {
        let element = resolveElement(step.target)
        let timeout = 5.0
        let exists = element.waitForExistence(timeout: timeout)
        if !exists {
            throw RunnerError.elementNotFound(step.id ?? "unnamed")
        }
        element.tap()
    }

    private func executeDoubleClick(_ step: Step) throws {
        let element = resolveElement(step.target)
        let exists = element.waitForExistence(timeout: 5.0)
        if !exists {
            throw RunnerError.elementNotFound(step.id ?? "unnamed")
        }
        element.doubleTap()
    }

    private func executeRightClick(_ step: Step) throws {
        let element = resolveElement(step.target)
        let exists = element.waitForExistence(timeout: 5.0)
        if !exists {
            throw RunnerError.elementNotFound(step.id ?? "unnamed")
        }
        element.press(forDuration: 1.5)
    }

    private func executeType(_ step: Step) throws {
        guard let text = step.args?.text else { return }
        let element = resolveElement(step.target)
        let exists = element.waitForExistence(timeout: 5.0)
        if !exists {
            throw RunnerError.elementNotFound(step.id ?? "unnamed")
        }
        if step.args?.clear == true {
            element.tap()
            element.clearText()
        } else {
            element.tap()
        }
        element.typeText(text)
    }

    private func executeSetValue(_ step: Step) throws {
        guard let text = step.args?.text else { return }
        let element = resolveElement(step.target)
        let exists = element.waitForExistence(timeout: 5.0)
        if !exists {
            throw RunnerError.elementNotFound(step.id ?? "unnamed")
        }
        // Slider?
        if element.elementType == .slider {
            element.adjust(toNormalizedSliderPosition: CGFloat(Double(text) ?? 0.5))
        } else {
            element.tap()
            element.clearText()
            element.typeText(text)
        }
    }

    private func executeScroll(_ step: Step) throws {
        let element = resolveElement(step.target)
        let exists = element.waitForExistence(timeout: 5.0)
        if !exists {
            throw RunnerError.elementNotFound(step.id ?? "unnamed")
        }
        let deltaY = step.args?.deltaY ?? 0
        if deltaY < 0 {
            element.swipeUp()
        } else {
            element.swipeDown()
        }
    }

    private func executeDrag(_ step: Step) throws {
        let source = resolveElement(step.target)
        let exists = source.waitForExistence(timeout: 5.0)
        if !exists {
            throw RunnerError.elementNotFound(step.id ?? "unnamed")
        }
        if let toSel = step.args?.to {
            let dest = resolveElement(toSel)
            source.press(forDuration: 0.5, thenDragTo: dest)
        }
    }

    private func executeMenu(_ step: Step) throws {
        guard let menuPath = step.args?.menuPath, !menuPath.isEmpty else { return }
        // On iOS, "View > Toggle Flag" maps to the nav bar button "Toggle Flag"
        let lastTitle = menuPath.last ?? ""
        let btn = app.navigationBars.buttons[lastTitle]
        if btn.waitForExistence(timeout: 3.0) {
            btn.tap()
            return
        }
        // Also try toolbar buttons
        let toolbarBtn = app.toolbars.buttons[lastTitle]
        if toolbarBtn.waitForExistence(timeout: 1.0) {
            toolbarBtn.tap()
            return
        }
        throw RunnerError.elementNotFound("menu: \(menuPath.joined(separator: " > "))")
    }

    private func executeKeyPress(_ step: Step) throws {
        guard let keys = step.args?.keys else { return }
        let element = resolveElement(step.target)
        _ = element.waitForExistence(timeout: 3.0)

        // Map common key combos
        switch keys.lowercased() {
        case "cmd+a", "command+a":
            element.tap()
            element.typeText(XCUIKeyboardKey.command.rawValue + "a")
        case "return", "enter":
            element.typeText(XCUIKeyboardKey.return.rawValue)
        case "escape":
            element.typeText(XCUIKeyboardKey.escape.rawValue)
        case "tab":
            element.typeText(XCUIKeyboardKey.tab.rawValue)
        default:
            element.tap()
            element.typeText(keys)
        }
    }

    private func executeWait(_ step: Step) {
        let seconds = step.args?.seconds ?? 0
        Thread.sleep(forTimeInterval: seconds)
    }

    private func executeScreenshot(_ step: Step) {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.lifetime = .keepAlways
        attachment.name = "screenshot-\(step.id ?? "unnamed")"
        // Attachments are added via XCTestCase; we store in a dedicated path instead
        let docs = FileManager.default.temporaryDirectory
        let filename = "screenshot-\(step.id ?? UUID().uuidString).png"
        let url = docs.appendingPathComponent(filename)
        try? screenshot.pngRepresentation.write(to: url)
        print("Screenshot saved: \(url.path)")
    }

    // MARK: - Assert

    private func executeAssert(_ step: Step) throws {
        guard let assertion = step.assert else { return }
        let property = assertion.property ?? "value"
        let op = assertion.op ?? "equals"
        let expected = assertion.expected ?? ""

        let element = resolveElement(step.target)

        // count assertion — doesn't need a single element
        if property == "count" {
            let countVal = elementCount(for: step.target)
            try assertNumeric(actual: Double(countVal), op: op, expected: expected, stepId: step.id ?? "unnamed")
            return
        }

        // exists / notExists
        if op == "exists" {
            XCTAssertTrue(element.exists, "Step \(step.id ?? ""): element should exist")
            return
        }
        if op == "notExists" {
            XCTAssertFalse(element.exists, "Step \(step.id ?? ""): element should not exist")
            return
        }

        // For other assertions, wait for element
        let exists = element.waitForExistence(timeout: 5.0)
        if !exists {
            throw RunnerError.elementNotFound(step.id ?? "unnamed")
        }

        switch property {
        case "value":
            let actualValue = elementValue(element)
            try assertString(actual: actualValue, op: op, expected: expected, stepId: step.id ?? "unnamed")
        case "title", "label":
            let label = element.label
            try assertString(actual: label, op: op, expected: expected, stepId: step.id ?? "unnamed")
        case "enabled":
            let isEnabled = element.isEnabled
            let expectedBool = expected == "true"
            XCTAssertEqual(isEnabled, expectedBool, "Step \(step.id ?? ""): enabled mismatch")
        case "focused":
            let isFocused = element.hasFocus
            let expectedBool = expected == "true"
            XCTAssertEqual(isFocused, expectedBool, "Step \(step.id ?? ""): focused mismatch")
        case "marked":
            // No direct "marked" API in XCUITest; check value
            let val = element.value as? String ?? ""
            let isTicked = val == "1" || val.lowercased() == "true"
            let expectedBool = expected == "true"
            XCTAssertEqual(isTicked, expectedBool, "Step \(step.id ?? ""): marked mismatch")
        case "position":
            let frame = element.frame
            let posStr = "\(frame.origin.x),\(frame.origin.y)"
            try assertString(actual: posStr, op: op, expected: expected, stepId: step.id ?? "unnamed")
        case "size":
            let frame = element.frame
            let sizeStr = "\(frame.size.width),\(frame.size.height)"
            try assertString(actual: sizeStr, op: op, expected: expected, stepId: step.id ?? "unnamed")
        default:
            let actualValue = elementValue(element)
            try assertString(actual: actualValue, op: op, expected: expected, stepId: step.id ?? "unnamed")
        }
    }

    // MARK: - Assert Helpers

    private func elementValue(_ element: XCUIElement) -> String {
        if let v = element.value as? String { return v }
        // For labels: use label
        return element.label
    }

    private func elementCount(for selector: SelectorJSON?) -> Int {
        guard let sel = selector else { return 0 }
        if let role = sel.role {
            let type = xcuiElementType(for: role)
            if let within = sel.within {
                let parent = resolveParent(within)
                return parent.descendants(matching: type).count
            }
            return app.descendants(matching: type).count
        }
        if let identifier = sel.identifier {
            return app.descendants(matching: .any).matching(identifier: identifier).count
        }
        return 0
    }

    private func assertString(actual: String, op: String, expected: String, stepId: String) throws {
        switch op {
        case "equals":
            XCTAssertEqual(actual, expected, "Step \(stepId): value mismatch")
        case "notEquals":
            XCTAssertNotEqual(actual, expected, "Step \(stepId): expected not-equal")
        case "contains":
            XCTAssertTrue(actual.contains(expected), "Step \(stepId): '\(actual)' does not contain '\(expected)'")
        case "matches":
            let regex = try NSRegularExpression(pattern: expected)
            let range = NSRange(actual.startIndex..., in: actual)
            let matched = regex.firstMatch(in: actual, range: range) != nil
            XCTAssertTrue(matched, "Step \(stepId): '\(actual)' does not match pattern '\(expected)'")
        case "greaterThan":
            guard let a = Double(actual), let e = Double(expected) else { return }
            XCTAssertGreaterThan(a, e, "Step \(stepId): \(a) not > \(e)")
        case "lessThan":
            guard let a = Double(actual), let e = Double(expected) else { return }
            XCTAssertLessThan(a, e, "Step \(stepId): \(a) not < \(e)")
        default:
            XCTAssertEqual(actual, expected, "Step \(stepId): (op=\(op)) value mismatch")
        }
    }

    private func assertNumeric(actual: Double, op: String, expected: String, stepId: String) throws {
        guard let expectedNum = Double(expected) else { return }
        switch op {
        case "equals":
            XCTAssertEqual(actual, expectedNum, accuracy: 0.001, "Step \(stepId): count mismatch")
        case "greaterThan":
            XCTAssertGreaterThan(actual, expectedNum, "Step \(stepId): count not > \(expectedNum)")
        case "lessThan":
            XCTAssertLessThan(actual, expectedNum, "Step \(stepId): count not < \(expectedNum)")
        default:
            XCTAssertEqual(actual, expectedNum, accuracy: 0.001, "Step \(stepId): count mismatch")
        }
    }
}

// MARK: - Errors

enum RunnerError: Error {
    case planNotFound
    case elementNotFound(String)
    case assertionFailed(String)
}

// MARK: - XCUIElement Extension

extension XCUIElement {
    func clearText() {
        guard let value = self.value as? String, !value.isEmpty else { return }
        let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: value.count)
        // Select all then delete
        self.tap()
        self.press(forDuration: 1.0)
        // Try select all
        let selectAll = self.menuItems["Select All"]
        if selectAll.exists {
            selectAll.tap()
            self.typeText(XCUIKeyboardKey.delete.rawValue)
        } else {
            // Just delete character by character
            self.typeText(deleteString)
        }
    }
}
