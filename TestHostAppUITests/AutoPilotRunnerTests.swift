import XCTest

class AutoPilotRunnerTests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = true
    }

    func testRunUnifiedPlan() throws {
        let app = XCUIApplication()
        app.launch()

        let runner = AutoPilotRunner(app: app)
        let results = try runner.run()

        // Report each step
        for result in results {
            if result.skipped {
                print("SKIPPED: \(result.id) — \(result.message)")
            } else if result.passed {
                print("PASS: \(result.id)")
            } else {
                print("FAIL: \(result.id) — \(result.message)")
            }
        }

        let failures = results.filter { !$0.skipped && !$0.passed }
        XCTAssert(
            failures.isEmpty,
            "Failed steps: \(failures.map(\.id).joined(separator: ", "))"
        )
    }
}
