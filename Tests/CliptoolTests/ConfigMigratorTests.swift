import Testing
import Foundation
import CJanet
import JanetKit
import TOMLKit

@Suite("ConfigMigrator") @MainActor struct ConfigMigratorTests {

    private func writeTemp(_ content: String) throws -> String {
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-\(UUID().uuidString).toml").path
        try content.write(toFile: path, atomically: true, encoding: .utf8)
        return path
    }

    @Test func emptyRules() throws {
        let toml = ""
        let path = try writeTemp(toml)
        let result = try ConfigMigrator.migrate(tomlPath: path)
        #expect(result == "")
    }

    @Test func jsonAlwaysRule() throws {
        let toml = #"""
        [[rule]]
        name = "Format JSON"
        match = "is_valid_json"
        steps = ["format_json"]
        when = "always"
        """#
        let path = try writeTemp(toml)
        let result = try ConfigMigrator.migrate(tomlPath: path)
        #expect(result.contains(#"(defrule "Format JSON" :always"#))
        #expect(result.contains("json/valid?"))
        #expect(result.contains("json/pretty"))
    }

    @Test func manualRule() throws {
        let toml = #"""
        [[rule]]
        name = "Manual Thing"
        match = "is_valid_json"
        steps = ["format_json"]
        when = "manual"
        """#
        let path = try writeTemp(toml)
        let result = try ConfigMigrator.migrate(tomlPath: path)
        #expect(result.contains(":manual"))
    }

    @Test func regexMatcher() throws {
        let toml = #"""
        [[rule]]
        name = "Regex Rule"
        match = { regex = "^GET" }
        steps = ["url_decode"]
        when = "manual"
        """#
        let path = try writeTemp(toml)
        let result = try ConfigMigrator.migrate(tomlPath: path)
        #expect(result.contains("string/find"))
        #expect(result.contains("string/percent-decode"))
    }

    @Test func janetMatcherAndStep() throws {
        let toml = #"""
        [[rule]]
        name = "Custom"
        match = { janet = "(valid? input)" }
        steps = [{ janet = "(process input)" }]
        when = "always"
        """#
        let path = try writeTemp(toml)
        let result = try ConfigMigrator.migrate(tomlPath: path)
        #expect(result.contains("(let [input s]"))
        #expect(result.contains("(valid? input)"))
        #expect(result.contains("(process input)"))
    }

    @Test func multiStep() throws {
        let toml = #"""
        [[rule]]
        name = "Chain"
        match = "is_valid_json"
        steps = ["url_decode", "base64_decode"]
        when = "always"
        """#
        let path = try writeTemp(toml)
        let result = try ConfigMigrator.migrate(tomlPath: path)
        #expect(result.contains("string/percent-decode"))
        #expect(result.contains("base64/decode"))
    }

    @Test func multiStepJanetThreads() throws {
        // Each step's body references `input`; the second step must receive the
        // first step's output, not the original clipboard value. That means the
        // second `(let [input ...])` must wrap the first step's body, and the
        // second body must NOT rebind `input` to `s`.
        let toml = #"""
        [[rule]]
        name = "Chain"
        match = "is_valid_json"
        steps = [{ janet = "(step1 input)" }, { janet = "(step2 input)" }]
        when = "always"
        """#
        let path = try writeTemp(toml)
        let result = try ConfigMigrator.migrate(tomlPath: path)
        #expect(result.contains("(let [input (let [input s] (step1 input))] (step2 input))"))
    }

    @Test func xmlRule() throws {
        let toml = #"""
        [[rule]]
        name = "XML Rule"
        match = "is_valid_xml"
        steps = ["sort"]
        when = "manual"
        """#
        let path = try writeTemp(toml)
        let result = try ConfigMigrator.migrate(tomlPath: path)
        #expect(result.contains("xml/valid?"))
    }

    @Test func jwtRule() throws {
        let toml = #"""
        [[rule]]
        name = "JWT"
        match = { regex = "^eyJ" }
        steps = ["jwt_payload"]
        when = "always"
        """#
        let path = try writeTemp(toml)
        let result = try ConfigMigrator.migrate(tomlPath: path)
        #expect(result.contains("extract-jwt-body"))
    }

    @Test func shellMapsToTodo() throws {
        let toml = #"""
        [[rule]]
        name = "Shell"
        match = { shell = "true" }
        steps = [{ shell = "cat" }]
        when = "manual"
        """#
        let path = try writeTemp(toml)
        let result = try ConfigMigrator.migrate(tomlPath: path)
        #expect(result.contains("TODO"))
    }

    @Test func shellMigrationProducesValidJanet() throws {
        // Regression: a shell matcher/step used to emit a bare `# TODO` line
        // comment. The step's comment was spliced into `(let [input ...] ...))`
        // and swallowed the closing parens, so the *entire* migrated file
        // failed to parse. The placeholders must be valid no-op Janet.
        let toml = #"""
        [[rule]]
        name = "Shell"
        match = { shell = "true" }
        steps = [{ shell = "cat" }]
        when = "manual"
        """#
        let path = try writeTemp(toml)
        let source = try ConfigMigrator.migrate(tomlPath: path)
        let vm = try JanetVM()
        _ = try vm.eval(source: source)  // must not throw
    }

    @Test func regexWithQuoteIsEscaped() throws {
        let toml = #"""
        [[rule]]
        name = "Quote"
        match = { regex = "a\"b" }
        steps = [{ janet = "(string/trim input)" }]
        when = "manual"
        """#
        let path = try writeTemp(toml)
        let result = try ConfigMigrator.migrate(tomlPath: path)
        // The embedded quote must be escaped so it doesn't terminate the
        // Janet string literal prematurely.
        #expect(result.contains("string/find \"a\\\"b\""))
    }

    @Test func nameWithQuoteIsEscaped() throws {
        let toml = #"""
        [[rule]]
        name = "a\"b"
        match = "is_valid_json"
        steps = ["format_json"]
        when = "always"
        """#
        let path = try writeTemp(toml)
        let result = try ConfigMigrator.migrate(tomlPath: path)
        #expect(result.contains("(defrule \"a\\\"b\" :always"))
    }

    @Test func migratedOutputIsValidJanetAndRegistersRules() throws {
        // End-to-end: the generated Janet must actually parse and register
        // rules when evaled. This catches escaping/quoting regressions that
        // substring checks would miss.
        RuleStorage.clear()
        let toml = #"""
        [[rule]]
        name = "Format JSON"
        match = "is_valid_json"
        steps = ["format_json"]
        when = "always"

        [[rule]]
        name = "GET Lines"
        match = { regex = "^GET" }
        steps = [{ janet = "(string/trim input)" }]
        when = "manual"
        """#
        let path = try writeTemp(toml)
        let source = try ConfigMigrator.migrate(tomlPath: path)

        let vm = try JanetVM()
        _ = try vm.eval(source: source)

        #expect(RuleStorage.rules.count == 2)
        #expect(RuleStorage.rules.contains { $0.name == "Format JSON" })
        #expect(RuleStorage.rules.contains { $0.name == "GET Lines" })
        #expect(RuleStorage.rules[0].trigger == .always)
        #expect(RuleStorage.rules[1].trigger == .manual)
        RuleStorage.clear()
    }

    @Test func everyMigratorEmittedSymbolResolves() throws {
        // Regression: every native step/matcher symbol the migrator can emit
        // must be a real, resolvable Janet binding. (Previously `jwt_payload`
        // -> extract-jwt-body and `url_decode` -> string/percent-decode were
        // emitted but undefined, so migrated configs failed to load.)
        let vm = try JanetVM()
        // Built-in matcher symbols.
        for matcher in ["json/valid?", "xml/valid?"] {
            _ = try vm.eval(source: matcher)
        }
        // Built-in step symbols referenced by janetForStep.
        for step in ["json/pretty", "base64/decode",
                     "extract-jwt-body", "string/percent-decode"] {
            _ = try vm.eval(source: step)
        }
    }
}
