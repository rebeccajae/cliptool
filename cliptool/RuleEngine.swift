import Foundation

import JanetKit

enum RuleEngine {
    
    private static let janet = try? JanetVM()
    
    static func evaluate(_ rules: [RuleConfig], input: String) -> (always: [RuleConfig], manual: [RuleConfig]) {
        let matching = rules.filter { matches($0.match, input: input) }
        let always = matching.filter { if case .always = $0.when { return true }; return false }
        let manual = matching.filter { if case .manual = $0.when { return true }; return false }
        return (always, manual)
    }

    static func apply(_ rule: RuleConfig, input: String) -> String? {
        var current = input
        for step in rule.steps {
            guard let result = applyStep(step, input: current) else { return nil }
            current = result
        }
        return current
    }

    private static func matches(_ matcher: Matcher, input: String) -> Bool {
        switch matcher {
        case .isValidJSON:
            guard let data = input.data(using: .utf8) else { return false }
            return (try? JSONSerialization.jsonObject(with: data)) != nil
        case .isValidXML:
            guard let data = input.data(using: .utf8) else { return false }
            return (try? XMLDocument(data: data)) != nil
        case .regex(let pattern):
            return (try? NSRegularExpression(pattern: pattern))
                .map { $0.firstMatch(in: input, range: NSRange(input.startIndex..., in: input)) != nil } ?? false
        case .janet(let source):
            do {
                let result = try RuleEngine.janet?.match(source: source, input: input) ?? false
                return result
            } catch {
                return false
            }
        case .shell:
            return false
        }
    }

    private static func applyStep(_ step: TransformStep, input: String) -> String? {
        switch step {
        case .formatJSON:
            return JSONFormatter.format(input)
        case .jwtPayload:
            let parts = input.split(separator: ".")
            guard parts.count == 3,
                  let data = Data(base64Encoded: String(parts[1])
                      .padding(toLength: ((String(parts[1]).count + 3) / 4) * 4, withPad: "=", startingAt: 0)) else { return nil }
            return String(data: data, encoding: .utf8)
        case .urlDecode:
            return input.removingPercentEncoding
        case .base64Decode:
            guard let data = Data(base64Encoded: input) else { return nil }
            return String(data: data, encoding: .utf8)
        case .sort:
            return input.split(separator: "\n").sorted().joined(separator: "\n")
        case .janet(let source):
            return try? RuleEngine.janet?.transform(source: source, input: input)
        case .shell:
            return nil
        }
    }
}
