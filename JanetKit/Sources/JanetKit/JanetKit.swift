import CJanet
import Foundation

public enum JanetError: Error {
    case initFailed
    case compileFailed(String)
    case runFailed(String)
    case unexpectedReturnType
}

public final class JanetVM {
    private var vm: UnsafeMutablePointer<JanetTable>?

    public init() throws {
        janet_init()
    }

    deinit {
        janet_deinit()
    }

    public func eval(source: String) throws -> Janet {
        let env = janet_core_env(nil)
        janet_register_extensions(env)
        var result = Janet()
        let status = janet_dostring(env, source, "eval", &result)
        guard status == JANET_SIGNAL_OK.rawValue else {
            throw JanetError.runFailed(source)
        }
        return result
    }

    public func match(source: String, input: String) throws -> Bool {
        // print("Input repr: \(input.debugDescription)")
        let wrapped = """
        (let [input \(quotedJanet(input))]
          \(source))
        """
        let result = try eval(source: wrapped)
        return janet_truthy(result) != 0
    }

    public func transform(source: String, input: String) throws -> String {
        let wrapped = """
        (let [input \(quotedJanet(input))]
          \(source))
        """
        let result = try eval(source: wrapped)
        guard let ptr = janet_unwrap_string(result) else {
            throw JanetError.unexpectedReturnType
        }
        return String(cString: ptr)
    }

    private func quotedJanet(_ s: String) -> String {
        let escaped = s
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
        return "\"\(escaped)\""
    }
}

@_silgen_name("janet_register_extensions")
func janet_register_extensions(_ env: UnsafeMutablePointer<JanetTable>?)
