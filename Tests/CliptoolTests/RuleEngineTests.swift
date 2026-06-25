import Testing
import CJanet
import JanetKit

@Suite("RuleEngine") struct RuleEngineTests {
    @Test func emptyRules() {
        let (always, manual) = RuleEngine.evaluate([], input: "anything")
        #expect(always.isEmpty)
        #expect(manual.isEmpty)
    }

    @Test func alwaysRuleMatches() throws {
        let vm = try JanetVM()
        RuleStorage.rules = []
        _ = try vm.eval(source: #"""
        (defrule "J" :always json/valid? json/pretty)
        """#)
        let rules = RuleStorage.rules
        #expect(rules.count == 1)

        let (always, manual) = RuleEngine.evaluate(rules, input: #"{"a":1}"#)
        #expect(always.count == 1)
        #expect(always[0].name == "J")
        #expect(manual.isEmpty)
    }

    @Test func alwaysRuleNonMatch() throws {
        let vm = try JanetVM()
        RuleStorage.rules = []
        _ = try vm.eval(source: #"""
        (defrule "J" :always json/valid? json/pretty)
        """#)
        let rules = RuleStorage.rules

        let (always, manual) = RuleEngine.evaluate(rules, input: "not json")
        #expect(always.isEmpty)
        #expect(manual.isEmpty)
    }

    @Test func manualRule() throws {
        let vm = try JanetVM()
        RuleStorage.rules = []
        _ = try vm.eval(source: #"""
        (defrule "M" :manual json/valid? json/pretty)
        """#)
        let rules = RuleStorage.rules

        let (always, manual) = RuleEngine.evaluate(rules, input: #"{"a":1}"#)
        #expect(always.isEmpty)
        #expect(manual.count == 1)
        #expect(manual[0].name == "M")
    }

    @Test func mixedRules() throws {
        let vm = try JanetVM()
        RuleStorage.rules = []
        _ = try vm.eval(source: #"""
        (defrule "Auto JSON" :always json/valid? json/pretty)
        (defrule "Manual JSON" :manual json/valid? (fn [s] (string/ascii-upper s)))
        """#)
        let rules = RuleStorage.rules
        #expect(rules.count == 2)

        let (always, manual) = RuleEngine.evaluate(rules, input: #"{"a":1}"#)
        #expect(always.count == 1)
        #expect(always[0].name == "Auto JSON")
        #expect(manual.count == 1)
        #expect(manual[0].name == "Manual JSON")
    }

    @Test func applyTransform() throws {
        let vm = try JanetVM()
        RuleStorage.rules = []
        _ = try vm.eval(source: #"""
        (defrule "Upper" :always (fn [s] true) (fn [s] (string/ascii-upper s)))
        """#)
        let rules = RuleStorage.rules

        let result = RuleEngine.apply(rules[0], input: "hello")
        #expect(result == "HELLO")
    }

    @Test func applyJsonFormat() throws {
        let vm = try JanetVM()
        RuleStorage.rules = []
        _ = try vm.eval(source: #"""
        (defrule "JSON" :always (fn [s] true) json/pretty)
        """#)
        let rules = RuleStorage.rules

        let result = RuleEngine.apply(rules[0], input: #"{"b":2,"a":1}"#)
        #expect(result?.contains(#""a" : 1"#) == true)
    }

    @Test func applyBadInputReturnsNil() throws {
        let vm = try JanetVM()
        RuleStorage.rules = []
        _ = try vm.eval(source: #"""
        (defrule "JSON" :always (fn [s] true) json/pretty)
        """#)
        let rules = RuleStorage.rules

        let result = RuleEngine.apply(rules[0], input: "not json")
        #expect(result == nil)
    }

    @Test func stressManyRules() throws {
        let vm = try JanetVM()
        RuleStorage.rules = []
        for i in 0..<50 {
            let src = "(defrule \"R\(i)\" :always (fn [s] (= s \"\(i)\")) (fn [s] s))"
            _ = try vm.eval(source: src)
        }
        let rules = RuleStorage.rules
        #expect(rules.count == 50)

        let (always, _) = RuleEngine.evaluate(rules, input: "7")
        #expect(always.count == 1)
        #expect(always[0].name == "R7")
    }
}
