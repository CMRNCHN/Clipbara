import Foundation
import SwiftData

enum SensitiveRuleKind: String, Codable, CaseIterable {
    case app
    case process
    case domain
}

/// A pattern that marks clipboard content as sensitive: captured encrypted at rest and auto-erased.
/// Distinct from `ExcludedApp`, which skips capture entirely.
@Model
final class SensitiveRule {

    var kindRaw: String
    var pattern: String
    var displayName: String

    var kind: SensitiveRuleKind {
        get { SensitiveRuleKind(rawValue: kindRaw) ?? .app }
        set { kindRaw = newValue.rawValue }
    }

    init(kind: SensitiveRuleKind, pattern: String, displayName: String) {
        self.kindRaw = kind.rawValue
        self.pattern = pattern
        self.displayName = displayName
    }
}
