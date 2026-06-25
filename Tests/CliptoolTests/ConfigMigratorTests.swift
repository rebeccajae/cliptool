import Testing
import Foundation
import TOMLKit

@Suite("ConfigMigrator") struct ConfigMigratorTests {

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
}
