import Foundation
import JanetKit
import TOMLKit
import CJanet

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
            
            output += "(defrule \(JanetVM.quoteString(name)) \(mode)\n"
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
                return "(fn [s] (not (nil? (string/find \(JanetVM.quoteString(r)) s))))"
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
        // Each step is a Janet *body* that references `input` (the current
        // value). We build a single `(fn [s] ...)` that threads `input` through
        // every step: each `(let [input <prev>] BODY)` rebinds `input` to the
        // previous step's result before evaluating the next body.
        let bodies: [String] = try array.map { try janetForStep($0.tomlValue) }
        guard !bodies.isEmpty else { throw MigrationError.missingValue("steps") }

        var acc = "s"
        for body in bodies {
            acc = "(let [input \(acc)] \(body))"
        }
        return "(fn [s] \(acc))"
    }

    /// Returns a Janet body expression that references `input` (the value being
    /// processed by this step). The caller wraps it so `input` is bound to the
    /// incoming value (or the previous step's output, when chaining).
    private static func janetForStep(_ toml: TOMLValue?) throws -> String {
        guard let toml else { throw MigrationError.unknownStep("missing step") }
        if let s = toml.string {
            switch s {
            case "format_json":   return "(json/pretty input)"
            case "jwt_payload":   return "(extract-jwt-body input)"
            case "url_decode":    return "(string/percent-decode input)"
            case "base64_decode": return "(base64/decode input)"
            case "sort":          return "(string/join (sort (string/split \"\\n\" input)) \"\\n\")"
            default: throw MigrationError.unknownStep(s)
            }
        } else if let t = toml.table {
            if let j = t["janet"]?.string {
                // User Janet references `input` directly.
                return j
            }
            if t["shell"] != nil {
                return "# TODO: shell step — replace with a Janet transform"
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
