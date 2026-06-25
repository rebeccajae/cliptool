import Foundation
import CJanet
import JanetKit

@MainActor
enum RuleEngine {
    /// Partition `rules` into those whose matcher accepts `input`.
    ///
    /// `vm` must be the same `JanetVM` that loaded the rules: the stored
    /// matcher/transform values are closures bound to that VM's environment.
    static func evaluate(
        _ rules: [RegisteredRule],
        input: String,
        vm: JanetVM
    ) -> (always: [RegisteredRule], manual: [RegisteredRule]) {
        let matching = rules.filter { matches($0, input: input, vm: vm) }
        let always = matching.filter { if case .always = $0.trigger { return true }; return false }
        let manual = matching.filter { if case .manual = $0.trigger { return true }; return false }
        return (always, manual)
    }

    /// Run a rule's transform against `input`, returning nil on any error so
    /// the clipboard is never clobbered with a bad result.
    static func apply(_ rule: RegisteredRule, input: String, vm: JanetVM) -> String? {
        guard let result = try? vm.callWithString(rule.transform, input: input),
              let ptr = janet_unwrap_string(result) else { return nil }
        return String(cString: ptr)
    }

    private static func matches(_ rule: RegisteredRule, input: String, vm: JanetVM) -> Bool {
        guard let result = try? vm.callWithString(rule.matcher, input: input) else { return false }
        return janet_truthy(result) != 0
    }
}
