import Foundation
import TOMLKit

struct RuleConfig {
    let name: String
    let match: Matcher
    let steps: [TransformStep]
    let when: TriggerMode
}

enum TriggerMode {
    case always
    case manual
}

enum Matcher {
    case isValidJSON
    case isValidXML
    case regex(String)
    case janet(String)
    case shell(String)
}

enum TransformStep {
    case formatJSON
    case jwtPayload
    case urlDecode
    case base64Decode
    case sort
    case janet(String)
    case shell(String)
}

extension RuleConfig {
    static func load(from path: String) throws -> [RuleConfig] {
        let contents = try String(contentsOfFile: path, encoding: .utf8)
        let table = try TOMLKit.TOMLTable(string: contents)
        let rulesValue = table["rule"]
        guard let rules = rulesValue?.array else { return [] }
        return try rules.compactMap { try RuleConfig(toml: $0.table!) }
    }

    init(toml: TOMLTable) throws {
        name = toml["name"]?.string ?? "Unnamed"
        when = toml["when"]?.string == "always" ? .always : .manual
        match = try Matcher(toml: toml["match"])
        let stepsArray = toml["steps"]?.array ?? TOMLArray()
        steps = try stepsArray.compactMap { try TransformStep(toml: $0.tomlValue) }
    }
}

extension Matcher {
    init(toml: TOMLValue?) throws {
        guard let toml else { throw ConfigError.missingMatcher }
        if let s = toml.string {
            switch s {
            case "is_valid_json": self = .isValidJSON
            case "is_valid_xml": self = .isValidXML
            default: throw ConfigError.unknownMatcher(s)
            }
        } else if let t = toml.table {
            if let r = t["regex"]?.string { self = .regex(r) }
            else if let j = t["janet"]?.string { self = .janet(j) }
            else if let s = t["shell"]?.string { self = .shell(s) }
            else { throw ConfigError.unknownMatcher("unknown table matcher") }
        } else {
            throw ConfigError.unknownMatcher("invalid matcher type")
        }
    }
}

extension TransformStep {
    init(toml: TOMLValue) throws {
        if let s = toml.string {
            switch s {
            case "format_json": self = .formatJSON
            case "jwt_payload": self = .jwtPayload
            case "url_decode": self = .urlDecode
            case "base64_decode": self = .base64Decode
            case "sort": self = .sort
            default: throw ConfigError.unknownStep(s)
            }
        } else if let t = toml.table {
            if let j = t["janet"]?.string { self = .janet(j) }
            else if let s = t["shell"]?.string { self = .shell(s) }
            else { throw ConfigError.unknownStep("unknown table step") }
        } else {
            throw ConfigError.unknownStep("invalid step type")
        }
    }
}

enum ConfigError: Error {
    case missingMatcher
    case unknownMatcher(String)
    case unknownStep(String)
}
