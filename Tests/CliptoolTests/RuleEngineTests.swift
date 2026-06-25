import Testing
import CJanet
import JanetKit

@Suite("RuleEngine") @MainActor struct RuleEngineTests {
    private static let vm = try! JanetVM()

    private func defn(_ source: String) throws -> Janet {
        try Self.vm.eval(source: source)
    }

    @Test func emptyRules() {
        let (always, manual) = RuleEngine.evaluate([], input: "anything", vm: Self.vm)
        #expect(always.isEmpty)
        #expect(manual.isEmpty)
    }

    @Test func alwaysRuleMatches() throws {
        RuleStorage.clear()
        let pred = try defn("(fn [s] true)")
        let xform = try defn("(fn [s] (string/ascii-upper s))")
        RuleStorage.rules = [RegisteredRule(name: "Test", trigger: .always, matcher: pred, transform: xform)]

        let (always, manual) = RuleEngine.evaluate(RuleStorage.rules, input: "hello", vm: Self.vm)
        #expect(always.count == 1)
        #expect(always[0].name == "Test")
        #expect(manual.isEmpty)

        let result = RuleEngine.apply(always[0], input: "hello", vm: Self.vm)
        #expect(result == "HELLO")
    }

    @Test func manualRule() throws {
        RuleStorage.clear()
        let pred = try defn("(fn [s] true)")
        RuleStorage.rules = [RegisteredRule(name: "Manual", trigger: .manual, matcher: pred, transform: pred)]

        let (always, manual) = RuleEngine.evaluate(RuleStorage.rules, input: "x", vm: Self.vm)
        #expect(always.isEmpty)
        #expect(manual.count == 1)
        #expect(manual[0].name == "Manual")
    }

    @Test func mixedRules() throws {
        RuleStorage.clear()
        let pred = try defn("(fn [s] true)")
        let xform = try defn("(fn [s] s)")
        RuleStorage.rules = [
            RegisteredRule(name: "Auto", trigger: .always, matcher: pred, transform: xform),
            RegisteredRule(name: "Manual", trigger: .manual, matcher: pred, transform: xform),
        ]

        let (always, manual) = RuleEngine.evaluate(RuleStorage.rules, input: "x", vm: Self.vm)
        #expect(always.count == 1)
        #expect(always[0].name == "Auto")
        #expect(manual.count == 1)
        #expect(manual[0].name == "Manual")
    }

    @Test func applyTransform() throws {
        RuleStorage.clear()
        let fn = try defn("(fn [s] (string/ascii-upper s))")
        RuleStorage.rules = [RegisteredRule(name: "U", trigger: .always, matcher: fn, transform: fn)]
        #expect(RuleEngine.apply(RuleStorage.rules[0], input: "hello", vm: Self.vm) == "HELLO")
    }

    @Test func applyBadInputReturnsNil() throws {
        RuleStorage.clear()
        let jp = try defn("json/pretty")
        RuleStorage.rules = [RegisteredRule(name: "J", trigger: .always, matcher: jp, transform: jp)]
        #expect(RuleEngine.apply(RuleStorage.rules[0], input: "not json", vm: Self.vm) == nil)
    }

    @Test func stressManyRules() throws {
        RuleStorage.clear()
        let eq = try defn("(fn [s] (= s \"7\"))")
        let id = try defn("(fn [s] s)")
        RuleStorage.rules = (0..<50).map { i in
            RegisteredRule(name: "R\(i)", trigger: .always, matcher: eq, transform: id)
        }
        let (always, _) = RuleEngine.evaluate(RuleStorage.rules, input: "7", vm: Self.vm)
        #expect(always.count == 50)
    }

    @Test func clearUnrootsRules() throws {
        RuleStorage.clear()
        let fn = try defn("(fn [s] s)")
        RuleStorage.rules = [RegisteredRule(name: "X", trigger: .always, matcher: fn, transform: fn)]
        #expect(!RuleStorage.rules.isEmpty)
        RuleStorage.clear()
        #expect(RuleStorage.rules.isEmpty)
        // Re-rooting an already-unrooted value is a no-op (returns 0).
        #expect(janet_gcunroot(fn) == 0)
    }
}
