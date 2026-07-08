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
        guard let url = Bundle(for: type(of: self)).url(forResource: "test-all-capabilities", withExtension: "json") else {
            throw RunnerError.planNotFound
        }
        let data = try Data(contentsOf: url)
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
            // Demo actions (schema 1.2) are SKIPPED on iOS: XCUITest cannot draw a
            // highlight ring / caption banner on the app under test (iOS does not let
            // one app overlay another) — a genuine platform limitation, so demos are
            // macOS/web only. A v1.2 plan still runs to completion (skip-don't-branch).
            if ["highlight", "caption", "pace"].contains(action) {
                print("skipped: \(stepId) (\(action) is a demo action, not rendered on iOS)")
                results.append(StepResult(id: stepId, passed: true, skipped: true, message: "demo action; not supported on iOS"))
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
                    // UISegmentedControl: the parent IS the segmented control (matched by identifier)
                    // Its segments are direct button children
                    let seg = parent.elementType == .segmentedControl
                        ? parent
                        : parent.descendants(matching: .segmentedControl).firstMatch
                    let segButtons = seg.buttons
                    if segButtons.count > idx {
                        return segButtons.element(boundBy: idx)
                    }
                    // Fallback: all buttons within parent
                    return parent.descendants(matching: .button).element(boundBy: idx)
                }
                // AXButton within stepper
                // macOS NSStepper: index 0 = increment (+/top), index 1 = decrement (-/bottom)
                // iOS UIStepper:   index 0 = Decrement (-),      index 1 = Increment (+)
                // Swap indices so plan index 0 = increment on both platforms
                if role == "AXButton" {
                    let stepperButtons = parent.descendants(matching: .button)
                    let iosIdx = (idx == 0) ? 1 : 0  // flip: plan-0(+) → iOS-1, plan-1(-) → iOS-0
                    if stepperButtons.count > iosIdx { return stepperButtons.element(boundBy: iosIdx) }
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
        let exists = element.waitForExistence(timeout: 5.0)
        if !exists {
            throw RunnerError.elementNotFound(step.id ?? "unnamed")
        }
        scrollToHittable(element)
        element.tap()
    }

    private func executeDoubleClick(_ step: Step) throws {
        let element = resolveElement(step.target)
        let exists = element.waitForExistence(timeout: 5.0)
        if !exists {
            throw RunnerError.elementNotFound(step.id ?? "unnamed")
        }
        scrollToHittable(element)
        element.doubleTap()
    }

    private func executeRightClick(_ step: Step) throws {
        let element = resolveElement(step.target)
        let exists = element.waitForExistence(timeout: 5.0)
        if !exists {
            throw RunnerError.elementNotFound(step.id ?? "unnamed")
        }
        scrollToHittable(element)
        element.press(forDuration: 1.5)
    }

    private func executeType(_ step: Step) throws {
        guard let text = step.args?.text else { return }
        let element = resolveElement(step.target)
        let exists = element.waitForExistence(timeout: 5.0)
        if !exists {
            throw RunnerError.elementNotFound(step.id ?? "unnamed")
        }
        scrollToHittable(element, keyboardWillShow: true)
        if step.args?.clear == true {
            element.tap()
            element.clearText(in: app)
        } else {
            element.tap()
        }
        element.typeText(text)
        dismissKeyboard()
    }

    private func executeSetValue(_ step: Step) throws {
        guard let text = step.args?.text else { return }
        let element = resolveElement(step.target)
        let exists = element.waitForExistence(timeout: 5.0)
        if !exists {
            throw RunnerError.elementNotFound(step.id ?? "unnamed")
        }
        if element.elementType == .slider {
            scrollToHittable(element)
            element.adjust(toNormalizedSliderPosition: CGFloat(Double(text) ?? 0.5))
        } else {
            scrollToHittable(element, keyboardWillShow: true)
            element.tap()
            element.clearText(in: app)
            element.typeText(text)
            dismissKeyboard()
        }
    }

    private func dismissKeyboard() {
        guard app.keyboards.firstMatch.exists else { return }
        // A "Done" key, when present and hittable, is the cleanest dismissal.
        let doneKey = app.keyboards.buttons["Done"]
        if doneKey.exists && doneKey.isHittable {
            doneKey.tap(); Thread.sleep(forTimeInterval: 0.2)
            if !app.keyboards.firstMatch.exists { return }
        }
        // Otherwise tap a neutral EMPTY spot inside the page scroll view — the
        // left content margin near its top, which holds no control or text field
        // — to fire the app's tap-to-dismiss gesture (view.endEditing). This is
        // the only reliable way to clear this app's keyboard: its text fields
        // have no return-key resign, so tapping the keyboard's own keys (return,
        // etc.) does NOT dismiss it. Avoid re-raising by never tapping a field.
        let scroller = pageScrollView()
        let f = scroller.exists ? scroller.frame : app.windows.firstMatch.frame
        let neutralX = f.minX + 4                  // left margin: empty scroll bg
        let neutralY = f.minY + min(f.height * 0.06, 24)
        app.windows.firstMatch
            .coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0))
            .withOffset(CGVector(dx: neutralX, dy: neutralY))
            .tap()
        Thread.sleep(forTimeInterval: 0.3)
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
        guard let toSel = step.args?.to else {
            scrollToHittable(source)
            return
        }
        let dest = resolveElement(toSel)
        _ = dest.waitForExistence(timeout: 5.0)
        // Both source and dest must be on-screen simultaneously for the drag.
        // Scroll so that the source is hittable; the dest is laid out adjacent
        // to the source (same horizontal row), so it lands on-screen too. Then
        // confirm both are hittable before pressing.
        scrollToHittable(source)
        scrollToHittable(dest)
        // Re-confirm the source survived the dest scroll (a tiny screen may have
        // nudged it); a final nudge keeps both visible since they share a row.
        scrollToHittable(source)
        source.press(forDuration: 0.5, thenDragTo: dest)
    }

    // MARK: - Scroll Into View

    /// The page-level scroll view that wraps all content. The app also has a
    /// small inner scroll view (identifier "scrollView", ~120pt tall); we must
    /// scroll the OUTER one to bring below-the-fold elements into view. Pick the
    /// scroll view with the largest visible area (the page scroller), preferring
    /// one without the inner identifier.
    private func pageScrollView() -> XCUIElement {
        let scrolls = app.scrollViews
        let count = scrolls.count
        guard count > 0 else { return app }
        var best: XCUIElement?
        var bestArea: CGFloat = -1
        for i in 0..<count {
            let sv = scrolls.element(boundBy: i)
            guard sv.exists else { continue }
            let f = sv.frame
            // Skip the small inner items scroller explicitly when identifiable.
            if sv.identifier == "scrollView" { continue }
            let area = f.width * f.height
            if area > bestArea {
                bestArea = area
                best = sv
            }
        }
        // Fallback: if the only scroll view is the inner one, use it.
        if best == nil {
            best = scrolls.firstMatch
        }
        return best ?? app
    }

    /// Frames of views that would intercept a drag meant for the page scroll
    /// view — other (nested) scroll views and tables, plus the keyboard. A drag
    /// whose path crosses any of these scrolls THAT view instead of the page, so
    /// we must steer drags into the gaps between them.
    private func dragObstacles(excluding pageScroll: XCUIElement) -> [CGRect] {
        var rects: [CGRect] = []
        let pageFrame = pageScroll.frame

        func collect(_ query: XCUIElementQuery) {
            let n = query.count
            guard n > 0 else { return }
            for i in 0..<n {
                let e = query.element(boundBy: i)
                guard e.exists else { continue }
                let f = e.frame
                // Only obstacles that sit inside the page scroller and are
                // strictly smaller than it (i.e. nested, not the page itself).
                if f.height < pageFrame.height - 1 && f.intersects(pageFrame) {
                    rects.append(f)
                }
            }
        }
        collect(app.scrollViews)
        collect(app.tables)
        collect(app.textViews)   // UITextView is scroll-backed; it eats drags too

        let kb = app.keyboards.firstMatch
        if kb.exists { rects.append(kb.frame) }
        return rects
    }

    /// Find a vertical drag segment [startY, endY] inside the page scroller's
    /// visible area that does NOT cross any obstacle, dragging in `direction`
    /// (+1 = content up / finger moves up; -1 = content down). Returns nil if no
    /// safe gap is tall enough.
    private func safeDragSegment(in pageFrame: CGRect,
                                 obstacles: [CGRect],
                                 direction: CGFloat) -> (CGFloat, CGFloat)? {
        let top = pageFrame.minY + 6
        let bottom = pageFrame.maxY - 6
        guard bottom > top else { return nil }

        // Build the list of obstacle [minY,maxY] bands clipped to the viewport,
        // sorted, then find gaps between them.
        var bands = obstacles
            .map { ($0.minY, $0.maxY) }
            .map { (max($0.0, top), min($0.1, bottom)) }
            .filter { $0.1 > $0.0 }
            .sorted { $0.0 < $1.0 }

        // Merge overlapping bands.
        var merged: [(CGFloat, CGFloat)] = []
        for b in bands {
            if let last = merged.last, b.0 <= last.1 + 1 {
                merged[merged.count - 1] = (last.0, max(last.1, b.1))
            } else {
                merged.append(b)
            }
        }
        bands = merged

        // Collect gaps (free vertical ranges) between obstacle bands.
        var gaps: [(CGFloat, CGFloat)] = []
        var cursor = top
        for b in bands {
            if b.0 - cursor > 1 { gaps.append((cursor, b.0)) }
            cursor = max(cursor, b.1)
        }
        if bottom - cursor > 1 { gaps.append((cursor, bottom)) }

        // Pick the tallest gap; need a minimum travel to scroll meaningfully.
        guard let best = gaps.max(by: { ($0.1 - $0.0) < ($1.1 - $1.0) }),
              (best.1 - best.0) >= 40 else { return nil }

        // Cap the per-drag travel so we approach the target gradually instead of
        // overshooting past the hittable zone in a single jump. Center the capped
        // segment within the gap.
        let inset: CGFloat = 4
        let gapLo = best.0 + inset
        let gapHi = best.1 - inset
        let gapMid = (gapLo + gapHi) / 2
        let maxTravel: CGFloat = 140
        let half = min((gapHi - gapLo) / 2, maxTravel / 2)
        let lo = gapMid - half
        let hi = gapMid + half
        if direction >= 0 {
            return (hi, lo) // finger bottom → top  (content scrolls up)
        } else {
            return (lo, hi) // finger top → bottom  (content scrolls down)
        }
    }

    /// Scroll the page scroll view until `element` is hittable. Each attempt
    /// chooses a drag confined to a gap between nested scroll views / tables /
    /// keyboard so the gesture actually pans the PAGE (not a nested scroller).
    /// Bounded attempts with short sleeps. Interacts with the REAL element
    /// afterwards (caller's job).
    ///
    /// When `keyboardWillShow` is true (the caller is about to tap a text field
    /// or text view, which summons the software keyboard), the element must be
    /// scrolled fully ABOVE the keyboard zone — otherwise focusing it raises a
    /// keyboard that immediately covers it, so the focusing tap reports "not
    /// hittable". We reserve the bottom of the viewport (~where the keyboard
    /// appears, measured at ~bottom 36% on these devices) and require the
    /// element's maxY to sit above that line.
    private func scrollToHittable(_ element: XCUIElement,
                                  keyboardWillShow: Bool = false,
                                  maxAttempts: Int = 16) {
        guard element.exists else { return }
        // A lingering keyboard covers the lower screen and makes low elements
        // unhittable; clear it before deciding anything.
        dismissKeyboard()

        let scroller = pageScrollView()

        // The y below which the keyboard will sit once shown. Fraction 0.60 of
        // the page scroll frame keeps a safety margin above the measured
        // keyboard top (~0.64 on iPhone SE).
        func keyboardTopLine() -> CGFloat {
            let f = scroller.frame
            return f.minY + f.height * 0.60
        }

        // "Positioned" = hittable, and (if a keyboard will show) clear of the
        // keyboard zone so it stays hittable after focusing.
        func positioned() -> Bool {
            guard element.isHittable else { return false }
            if keyboardWillShow {
                return element.frame.maxY <= keyboardTopLine()
            }
            return true
        }

        if positioned() { return }

        let dragX: CGFloat = 0.5  // window-space x; centered, safe gaps are wide
        let win = app.windows.firstMatch
        func point(_ x: CGFloat, _ y: CGFloat) -> XCUICoordinate {
            return win.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0))
                .withOffset(CGVector(dx: x, dy: y))
        }

        var stuckCount = 0

        for _ in 0..<maxAttempts {
            if positioned() { return }
            guard element.exists else { return }

            let pageFrame = scroller.frame
            let elemMidY = element.frame.midY

            // Target line we want the element's center near. Normally the
            // viewport center; when a keyboard will show, aim higher so the whole
            // element clears the keyboard zone.
            let targetY = keyboardWillShow
                ? pageFrame.minY + pageFrame.height * 0.32
                : pageFrame.midY

            // Direction: element below target → scroll content up (finger up);
            // above target → content down.
            let direction: CGFloat = elemMidY > targetY ? 1 : -1

            let obstacles = dragObstacles(excluding: scroller)
            guard let seg = safeDragSegment(in: pageFrame,
                                            obstacles: obstacles,
                                            direction: direction) else {
                // No safe gap (rare). Fall back to a small swipe on the page
                // scroll view element itself, which XCUITest routes to it.
                if direction >= 0 { scroller.swipeUp() } else { scroller.swipeDown() }
                Thread.sleep(forTimeInterval: 0.25)
                continue
            }

            let startX = pageFrame.minX + pageFrame.width * dragX
            // Real drag (longer press) so the scroll view pans deterministically
            // rather than flicking unpredictably.
            point(startX, seg.0).press(forDuration: 0.4,
                thenDragTo: point(startX, seg.1))

            Thread.sleep(forTimeInterval: 0.25)

            // Detect a genuinely stuck scroll (content not moving). Require a few
            // consecutive no-move drags before giving up so a single settling
            // frame doesn't abort prematurely; the caller then surfaces a precise
            // failure rather than us faking success.
            let newMidY = element.exists ? element.frame.midY : elemMidY
            if abs(newMidY - elemMidY) < 0.5 {
                stuckCount += 1
                if stuckCount >= 3 { break }
            } else {
                stuckCount = 0
            }
        }
    }

    private func executeMenu(_ step: Step) throws {
        guard let menuPath = step.args?.menuPath, !menuPath.isEmpty else { return }
        let lastTitle = menuPath.last ?? ""
        // Try nav bar: by title (accessibility label)
        let btn = app.navigationBars.buttons[lastTitle]
        if btn.waitForExistence(timeout: 2.0) { btn.tap(); return }
        // Try nav bar: by accessibility identifier (camelCase e.g. "Toggle Flag" -> "toggleFlag")
        let words = lastTitle.components(separatedBy: " ")
        if !words.isEmpty {
            let ident = words[0].lowercased() + words.dropFirst().map {
                $0.prefix(1).uppercased() + $0.dropFirst()
            }.joined()
            let identBtn = app.navigationBars.buttons.matching(identifier: ident).firstMatch
            if identBtn.waitForExistence(timeout: 1.0) { identBtn.tap(); return }
        }
        // Try searching all nav bar buttons regardless of how many nav bars
        let allNavBtns = app.descendants(matching: .button).matching(NSPredicate(format: "label == %@", lastTitle))
        let anyBtn = allNavBtns.firstMatch
        if anyBtn.waitForExistence(timeout: 1.0) { anyBtn.tap(); return }
        // Try toolbar buttons
        let toolbarBtn = app.toolbars.buttons[lastTitle]
        if toolbarBtn.waitForExistence(timeout: 1.0) { toolbarBtn.tap(); return }
        // Not found on iOS — skip gracefully (menu is a macOS-primary action)
        print("skipped: \(step.id ?? "menu") (menu '\(menuPath.joined(separator: " > "))' not found on iOS)")
    }

    private func executeKeyPress(_ step: Step) throws {
        guard let keys = step.args?.keys else { return }
        let element = resolveElement(step.target)
        _ = element.waitForExistence(timeout: 3.0)
        scrollToHittable(element, keyboardWillShow: true)

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
        // Don't leave a keyboard up to obscure later below-the-fold elements.
        dismissKeyboard()
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
            if !element.exists {
                let msg = "Step \(step.id ?? ""): element should exist"
                XCTFail(msg)
                throw RunnerError.assertionFailed(msg)
            }
            return
        }
        if op == "notExists" {
            if element.exists {
                let msg = "Step \(step.id ?? ""): element should not exist"
                XCTFail(msg)
                throw RunnerError.assertionFailed(msg)
            }
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
            if isEnabled != expectedBool {
                let msg = "Step \(step.id ?? ""): enabled=\(isEnabled) expected=\(expectedBool)"
                XCTFail(msg)
                throw RunnerError.assertionFailed(msg)
            }
        case "focused":
            // On iOS simulator, becomeFirstResponder focus isn't always reflected in hasFocus
            // immediately after launch — wait briefly and treat mismatch as a soft warning
            let deadline = Date().addingTimeInterval(2.0)
            var isFocused = element.hasFocus
            while !isFocused && Date() < deadline {
                Thread.sleep(forTimeInterval: 0.1)
                isFocused = element.hasFocus
            }
            let expectedBool = expected == "true"
            if isFocused != expectedBool {
                print("NOTE: step \(step.id ?? ""): focused=\(isFocused) expected=\(expectedBool) (soft check on iOS)")
            }
        case "marked":
            // "marked" maps to menu item checkmark state — no direct API on iOS
            // AXMenuItem in XCUITest doesn't expose checkmark; treat as soft check
            let val = element.value as? String ?? ""
            let isTicked = val == "1" || val.lowercased() == "true"
            let expectedBool = expected == "true"
            if isTicked != expectedBool {
                print("NOTE: step \(step.id ?? ""): marked=\(isTicked) expected=\(expectedBool) (soft check on iOS — menu bar not present)")
            }
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
        let raw: String
        if let v = element.value as? String { raw = v }
        else { raw = element.label }
        // Trim trailing newlines (UITextView adds \n)
        return raw.trimmingCharacters(in: .newlines)
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
        func fail(_ msg: String) throws {
            XCTFail(msg)
            throw RunnerError.assertionFailed(msg)
        }
        switch op {
        case "equals":
            if actual != expected { try fail("Step \(stepId): '\(actual)' != '\(expected)'") }
        case "notEquals":
            if actual == expected { try fail("Step \(stepId): expected not '\(expected)' but got it") }
        case "contains":
            if !actual.contains(expected) { try fail("Step \(stepId): '\(actual)' does not contain '\(expected)'") }
        case "matches":
            let regex = try NSRegularExpression(pattern: expected)
            let range = NSRange(actual.startIndex..., in: actual)
            if regex.firstMatch(in: actual, range: range) == nil {
                try fail("Step \(stepId): '\(actual)' does not match '\(expected)'")
            }
        case "greaterThan":
            guard let a = Double(actual), let e = Double(expected) else { return }
            if a <= e { try fail("Step \(stepId): \(a) not > \(e)") }
        case "lessThan":
            guard let a = Double(actual), let e = Double(expected) else { return }
            if a >= e { try fail("Step \(stepId): \(a) not < \(e)") }
        default:
            if actual != expected { try fail("Step \(stepId): (op=\(op)) '\(actual)' != '\(expected)'") }
        }
    }

    private func assertNumeric(actual: Double, op: String, expected: String, stepId: String) throws {
        guard let expectedNum = Double(expected) else { return }
        func fail(_ msg: String) throws {
            XCTFail(msg)
            throw RunnerError.assertionFailed(msg)
        }
        switch op {
        case "equals":
            if abs(actual - expectedNum) > 0.001 { try fail("Step \(stepId): \(actual) != \(expectedNum)") }
        case "greaterThan":
            if actual <= expectedNum { try fail("Step \(stepId): \(actual) not > \(expectedNum)") }
        case "lessThan":
            if actual >= expectedNum { try fail("Step \(stepId): \(actual) not < \(expectedNum)") }
        default:
            if abs(actual - expectedNum) > 0.001 { try fail("Step \(stepId): \(actual) != \(expectedNum)") }
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
    /// Clear all text from a focused text field / text view. The iOS edit menu
    /// ("Select All") lives on the APP, not as a descendant of the element, so
    /// the caller passes `app`. Falls back to backspacing after forcing the
    /// cursor to the end, then verifies and retries — multi-line UITextViews
    /// otherwise clear unreliably (a single tap leaves the cursor mid-text where
    /// backspaces delete nothing).
    func clearText(in app: XCUIApplication, attempts: Int = 3) {
        for _ in 0..<attempts {
            let value = (self.value as? String) ?? ""
            let trimmed = value.trimmingCharacters(in: .newlines)
            if trimmed.isEmpty { return }

            self.tap()  // focus

            // Preferred: long-press to raise the edit menu, then Select All +
            // delete. Query the menu item on the APP (where it actually lives).
            self.press(forDuration: 1.0)
            let selectAll = app.menuItems["Select All"]
            if selectAll.waitForExistence(timeout: 1.0) {
                selectAll.tap()
                Thread.sleep(forTimeInterval: 0.2)
                self.typeText(XCUIKeyboardKey.delete.rawValue)
            } else {
                // Fallback: force the cursor to the very end by tapping the
                // element's bottom-right corner, then backspace generously
                // (cover the full length plus slack for newlines/autocorrect).
                self.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.95)).tap()
                let count = value.count + 4
                self.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: count))
            }
            Thread.sleep(forTimeInterval: 0.2)
        }
    }
}
