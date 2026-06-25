import Foundation
import CJanet

/// Called from C (janet_extensions.c) when `defrule` is invoked during config
/// eval. Runs on the Janet thread, which (via `@MainActor` on `JanetVM`) is the
/// main thread.
@_cdecl("clipfmt_add_rule")
func clipfmt_add_rule(mode: Int32, name: UnsafePointer<CChar>, matcher: Janet, transform: Janet) {
    let trigger: TriggerMode = (mode == 0) ? .always : .manual
    let ruleName = String(cString: name)
    // `defrule_cfun` already rooted these values; RuleStorage owns their
    // lifetime and unroots them on `clear()`.
    RuleStorage.rules.append(RegisteredRule(
        name: ruleName,
        trigger: trigger,
        matcher: matcher,
        transform: transform
    ))
}

/// Collects rules during a config load. Cleared (and unrooted) before each
/// reload so stale Janet function values can be garbage-collected.
@MainActor
enum RuleStorage {
    nonisolated(unsafe) static var rules: [RegisteredRule] = []

    /// Drop every registered rule, unrooting the Janet values that
    /// `defrule_cfun` rooted. Must run on the main (Janet) thread.
    static func clear() {
        for rule in rules {
            _ = janet_gcunroot(rule.matcher)
            _ = janet_gcunroot(rule.transform)
        }
        rules = []
    }
}
