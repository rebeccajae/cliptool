import Foundation

enum JSONFormatter {
    static func format(_ input: String) -> String? {
        guard let data = input.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data),
              let pretty = try? JSONSerialization.data(
                  withJSONObject: object,
                  options: [.prettyPrinted, .sortedKeys]
              ) else { return nil }
        return String(data: pretty, encoding: .utf8)
    }
}
