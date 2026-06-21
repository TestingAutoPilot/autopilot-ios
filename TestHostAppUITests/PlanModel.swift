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

struct Step: Codable {
    let id: String?
    let comment: String?
    let action: String?
    let target: SelectorJSON?
    let args: ArgsJSON?
    let assert: AssertJSON?

    enum CodingKeys: String, CodingKey {
        case id, comment, action, target, args, assert
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
}

// MARK: - Assert

struct AssertJSON: Codable {
    let property: String?
    let op: String?
    let expected: String?
}
