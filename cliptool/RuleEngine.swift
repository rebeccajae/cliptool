import Foundation
import CJanet
import JanetKit

enum RuleEngine {
    nonisolated(unsafe) static let janet = try? JanetVM()

    static func evaluate(_ rules: [RegisteredRule], input: String) -> (always: [RegisteredRule], manual: [RegisteredRule]) {
        let matching = rules.filter { matches($0, input: input) }
        let always = matching.filter { if case .always = $0.trigger { return true }; return false }
        let manual = matching.filter { if case .manual = $0.trigger { return true }; return false }
        return (always, manual)
    }

    static func apply(_ rule: RegisteredRule, input: String) -> String? {
        guard let vm = janet,
              let result = try? vm.callWithString(rule.transform, input: input),
              let ptr = janet_unwrap_string(result) else { return nil }
        return String(cString: ptr)
    }

    private static func matches(_ rule: RegisteredRule, input: String) -> Bool {
        guard let vm = janet,
              let result = try? vm.callWithString(rule.matcher, input: input) else { return false }
        return janet_truthy(result) != 0
    }
}
