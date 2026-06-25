import Testing
import CJanet
import JanetKit

@Suite("RuleEngine") struct RuleEngineTests {

    /// Define a function and return its Janet value, all in one eval.
    private func defn(_ source: String) throws -> Janet {
        try RuleEngine.janet!.eval(source: source)
    }

    @Test func emptyRules() {
        let (always, manual) = RuleEngine.evaluate([], input: "anything")
        #expect(always.isEmpty)
        #expect(manual.isEmpty)
    }

    @Test func alwaysRuleMatches() throws {
        RuleStorage.rules = []
        let pred = try defn("(fn [s] true)")
        let xform = try defn("(fn [s] (string/ascii-upper s))")
        RuleStorage.rules = [RegisteredRule(name: "Test", trigger: .always, matcher: pred, transform: xform)]

        let (always, manual) = RuleEngine.evaluate(RuleStorage.rules, input: "hello")
        #expect(always.count == 1)
        #expect(always[0].name == "Test")
        #expect(manual.isEmpty)

        let result = RuleEngine.apply(always[0], input: "hello")
        #expect(result == "HELLO")
    }

    @Test func manualRule() throws {
        RuleStorage.rules = []
        let pred = try defn("(fn [s] true)")
        RuleStorage.rules = [RegisteredRule(name: "Manual", trigger: .manual, matcher: pred, transform: pred)]

        let (always, manual) = RuleEngine.evaluate(RuleStorage.rules, input: "x")
        #expect(always.isEmpty)
        #expect(manual.count == 1)
        #expect(manual[0].name == "Manual")
    }

    @Test func mixedRules() throws {
        RuleStorage.rules = []
        let pred = try defn("(fn [s] true)")
        let xform = try defn("(fn [s] s)")
        RuleStorage.rules = [
            RegisteredRule(name: "Auto", trigger: .always, matcher: pred, transform: xform),
            RegisteredRule(name: "Manual", trigger: .manual, matcher: pred, transform: xform),
        ]

        let (always, manual) = RuleEngine.evaluate(RuleStorage.rules, input: "x")
        #expect(always.count == 1)
        #expect(always[0].name == "Auto")
        #expect(manual.count == 1)
        #expect(manual[0].name == "Manual")
    }

    @Test func applyTransform() throws {
        RuleStorage.rules = []
        let fn = try defn("(fn [s] (string/ascii-upper s))")
        RuleStorage.rules = [RegisteredRule(name: "U", trigger: .always, matcher: fn, transform: fn)]
        #expect(RuleEngine.apply(RuleStorage.rules[0], input: "hello") == "HELLO")
    }

    @Test func applyBadInputReturnsNil() throws {
        RuleStorage.rules = []
        let jp = try defn("json/pretty")
        RuleStorage.rules = [RegisteredRule(name: "J", trigger: .always, matcher: jp, transform: jp)]
        #expect(RuleEngine.apply(RuleStorage.rules[0], input: "not json") == nil)
    }

    @Test func stressManyRules() throws {
        RuleStorage.rules = []
        let eq = try defn("(fn [s] (= s \"7\"))")
        let id = try defn("(fn [s] s)")
        RuleStorage.rules = (0..<50).map { i in
            RegisteredRule(name: "R\(i)", trigger: .always, matcher: eq, transform: id)
        }
        let (always, _) = RuleEngine.evaluate(RuleStorage.rules, input: "7")
        #expect(always.count == 50)
    }
}
