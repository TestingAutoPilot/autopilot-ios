import Foundation

// MARK: - Root Plan

struct Plan: Codable {
    let schemaVersion: String
    let name: String
    let target: TargetApp
    let defaults: PlanDefaults?
    let steps: [Step]
}

struct TargetApp: Codable {
    let bundleId: String?
}

struct PlanDefaults: Codable {
    let timeoutMs: Int?
    let retryIntervalMs: Int?
}

/// Coverage tier of a step: cumulative happyPath ⊂ integrationSuite ⊂ tryToBreakIt.
/// Mirrors autopilot-core's StepLevel. A LABEL — it does not invert pass/fail.
enum StepLevel: String, Codable, CaseIterable {
    case happyPath
    case integrationSuite
    case tryToBreakIt

    var rank: Int {
        switch self {
        case .happyPath: return 0
        case .integrationSuite: return 1
        case .tryToBreakIt: return 2
        }
    }
}

struct Step: Codable {
    let id: String?
    let comment: String?
    let action: String?
    /// REQUIRED coverage tier. Enforced at decode time to match autopilot-core:
    /// a step with a missing or invalid `level` is rejected with a clear error.
    let level: StepLevel
    let target: SelectorJSON?
    let args: ArgsJSON?
    let assert: AssertJSON?

    enum CodingKeys: String, CodingKey {
        case id, comment, action, level, target, args, assert
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id)
        comment = try c.decodeIfPresent(String.self, forKey: .comment)
        action = try c.decodeIfPresent(String.self, forKey: .action)
        target = try c.decodeIfPresent(SelectorJSON.self, forKey: .target)
        args = try c.decodeIfPresent(ArgsJSON.self, forKey: .args)
        assert = try c.decodeIfPresent(AssertJSON.self, forKey: .assert)

        let stepId = id ?? "?"
        let valid = StepLevel.allCases.map(\.rawValue).joined(separator: ", ")
        guard let raw = try c.decodeIfPresent(String.self, forKey: .level) else {
            throw DecodingError.dataCorruptedError(
                forKey: .level, in: c,
                debugDescription: "step \(stepId): missing required field `level` — use \(valid)")
        }
        guard let parsed = StepLevel(rawValue: raw) else {
            throw DecodingError.dataCorruptedError(
                forKey: .level, in: c,
                debugDescription: "step \(stepId): invalid level '\(raw)' — use \(valid)")
        }
        level = parsed
    }
}

// MARK: - Selector

// Using a class for indirect recursion (within: SelectorJSON?)
class SelectorJSON: Codable {
    let identifier: String?
    let role: String?
    let title: String?
    let index: Int?
    let within: SelectorJSON?

    required init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        identifier = try c.decodeIfPresent(String.self, forKey: .identifier)
        role = try c.decodeIfPresent(String.self, forKey: .role)
        title = try c.decodeIfPresent(String.self, forKey: .title)
        index = try c.decodeIfPresent(Int.self, forKey: .index)
        within = try c.decodeIfPresent(SelectorJSON.self, forKey: .within)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(identifier, forKey: .identifier)
        try c.encodeIfPresent(role, forKey: .role)
        try c.encodeIfPresent(title, forKey: .title)
        try c.encodeIfPresent(index, forKey: .index)
        try c.encodeIfPresent(within, forKey: .within)
    }

    enum CodingKeys: String, CodingKey {
        case identifier, role, title, index, within
    }
}

// MARK: - Args

struct ArgsJSON: Codable {
    let text: String?
    let clear: Bool?
    let focus: Bool?
    let commit: Bool?
    let present: Bool?
    let seconds: Double?
    let deltaY: Double?
    let to: SelectorJSON?
    let menuPath: [String]?
    let color: String?
    let tolerance: Int?
    let keys: String?
    let padding: Int?
    let reference: String?
    let width: Int?
    let height: Int?
    let mode: String?
    // Demo args (schema 1.2). Present so a v1.2 demo plan decodes cleanly; the demo
    // actions (highlight/caption/pace) are SKIPPED on iOS — XCUITest cannot overlay
    // the app under test, a genuine platform limitation. See AutoPilotRunner's skip.
    let holdMs: Int?
    let position: String?
    let typeMsPerChar: Int?
    let stepDelayMs: Int?
}

// MARK: - Assert

struct AssertJSON: Codable {
    let property: String?
    let op: String?
    let expected: String?
}
