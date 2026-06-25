import Foundation
import CJanet

/// Called from C (janet_extensions.c) when `defrule` is invoked during config eval.
@_cdecl("clipfmt_add_rule")
func clipfmt_add_rule(mode: Int32, name: UnsafePointer<CChar>, matcher: Janet, transform: Janet) {
    let trigger: TriggerMode = (mode == 0) ? .always : .manual
    let ruleName = String(cString: name)
    RuleStorage.rules.append(RegisteredRule(
        name: ruleName,
        trigger: trigger,
        matcher: matcher,
        transform: transform
    ))
}

/// Collects rules during config load. Cleared before each eval.
enum RuleStorage {
    nonisolated(unsafe) static var rules: [RegisteredRule] = []
}
