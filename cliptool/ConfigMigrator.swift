import Foundation
import TOMLKit

struct ConfigMigrator {
    
    static func migrate(tomlPath: String) throws -> String {
        let contents = try String(contentsOfFile: tomlPath, encoding: .utf8)
        let table = try TOMLTable(string: contents)
        let rulesValue = table["rule"]
        guard let rules = rulesValue?.array else { return "" }
        
        var output = ""
        output += "# Converted from TOML config\n"
        output += "# Review the output: shell matchers/steps and custom Janet expressions\n"
        output += "# that reference `input` are wrapped in a (let [input s] ...) shim.\n\n"
        
        for rule in rules {
            guard let ruleTable = rule.table else { continue }
            let name = ruleTable["name"]?.string ?? "Unnamed"
            let mode = ruleTable["when"]?.string == "always" ? ":always" : ":manual"
            
            let matcherJanet = try janetForMatcher(ruleTable["match"])
            let transformJanet = try janetForSteps(ruleTable["steps"]?.array ?? TOMLArray())
            
            output += "(defrule \"\(name)\" \(mode)\n"
            output += "  \(matcherJanet)\n"
            output += "  \(transformJanet))\n\n"
        }
        
        return output
    }
    
    private static func janetForMatcher(_ toml: TOMLValue?) throws -> String {
        guard let toml else { throw MigrationError.missingValue("match") }
        if let s = toml.string {
            switch s {
            case "is_valid_json": return "json/valid?"
            case "is_valid_xml":  return "xml/valid?"
            default: throw MigrationError.unknownMatcher(s)
            }
        } else if let t = toml.table {
            if let j = t["janet"]?.string {
                return "(fn [s] (let [input s] \(j)))"
            }
            if let r = t["regex"]?.string {
                return "(fn [s] (not (nil? (string/find \"\(r)\" s))))"
            }
            if t["shell"] != nil {
                return "# TODO: shell matcher — replace with a Janet predicate"
            }
            throw MigrationError.unknownMatcher("unknown table matcher")
        } else {
            throw MigrationError.unknownMatcher("invalid matcher type")
        }
    }
    
    private static func janetForSteps(_ array: TOMLArray) throws -> String {
        let steps: [(native: Bool, expr: String)] = try array.compactMap {
            guard let s = try janetForStep($0.tomlValue) else { return nil }
            return s
        }
        guard !steps.isEmpty else { throw MigrationError.missingValue("steps") }

        // All native, single step: just the function name
        if steps.count == 1, steps[0].native {
            return steps[0].expr
        }

        // Compose: apply each step in order, threading `input` through
        if steps.allSatisfy({ $0.native }) {
            let chain = steps.dropFirst().reduce(steps[0].expr) { "(\($1.expr) \($0))" }
            return "(fn [s] \(chain))"
        }

        // Janet expressions need the (let [input s] ...) shim
        let chain = steps.dropFirst().reduce(steps[0].expr) { "(let [input \($0)] \($1.expr))" }
        return "(fn [s] (let [input s] \(chain)))"
    }
    
    private static func janetForStep(_ toml: TOMLValue?) throws -> (native: Bool, expr: String)? {
        guard let toml else { return nil }
        if let s = toml.string {
            switch s {
            case "format_json":   return (true, "json/pretty")
            case "jwt_payload":   return (true, "extract-jwt-body")
            case "url_decode":    return (true, "string/percent-decode")
            case "base64_decode": return (true, "base64/decode")
            case "sort":
                return (false, "(fn [s] (string/join (sort (string/split \"\\n\" s)) \"\\n\"))")
            default: throw MigrationError.unknownStep(s)
            }
        } else if let t = toml.table {
            if let j = t["janet"]?.string {
                return (false, "(let [input s] \(j))")
            }
            if t["shell"] != nil {
                return (false, "# TODO: shell step — replace with a Janet transform")
            }
            throw MigrationError.unknownStep("unknown table step")
        } else {
            throw MigrationError.unknownStep("invalid step type")
        }
    }
}

enum MigrationError: Error {
    case missingValue(String)
    case unknownMatcher(String)
    case unknownStep(String)
}
