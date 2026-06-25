import CJanet
import Foundation

public enum JanetError: Error {
    case initFailed
    case compileFailed(String)
    case runFailed(String)
    case unexpectedReturnType
}

/// A handle to the Janet runtime.
///
/// Janet's VM state is thread-local (`JANET_THREAD_LOCAL JanetVM janet_vm`)
/// and not safe to share across threads: each OS thread that wants to use
/// Janet must call `janet_init` itself, and function values compiled against
/// one thread's core environment cannot necessarily be called on another.
///
/// To make this tractable, `JanetVM` is bound to the `@MainActor`. All Janet
/// work in the app already happens on the main thread (the clipboard timer,
/// the config watcher, and menu actions all run on `.main`), and binding the
/// type to the main actor lets the compiler enforce that tests do the same.
///
/// Beyond threading, every instance shares the single main-thread core
/// environment (built once and registered with our C extensions), and each
/// instance gets its own "user environment" — a table whose prototype is the
/// core env — so top-level `def`s from one instance don't leak into another.
@MainActor
public final class JanetVM {

    // MARK: - Global, one-time initialisation (main-thread only)

    private nonisolated(unsafe) static let coreEnv: UnsafeMutablePointer<JanetTable> = {
        janet_init()
        let env = janet_core_env(nil)!
        clipfmt_defrule_cfun(env)
        clipfmtRegisterSwiftExtensions(env)
        // Root the core env so Janet's conservative GC (which only scans the
        // C stack) never collects it from the Swift heap.
        janet_gcroot(janet_wrap_table(env))
        return env
    }()

    // MARK: - Per-instance user environment

    private let userEnv: UnsafeMutablePointer<JanetTable>

    public init() throws {
        // Touch the global initialiser exactly once.
        let core = JanetVM.coreEnv
        // Fresh child environment: top-level defs land here, while core
        // bindings (json/valid?, defrule, ...) resolve via the prototype.
        let env = janet_table(0)!
        env.pointee.proto = core
        self.userEnv = env
    }

    /// Evaluate source in this VM's user environment.
    public func eval(source: String) throws -> Janet {
        var result = Janet()
        let status = janet_dostring(userEnv, source, "eval", &result)
        guard status == JANET_SIGNAL_OK.rawValue else {
            // janet_dostring writes the error value into `result`; surface its
            // string form so callers can show what actually went wrong.
            let detail = Self.describe(result)
            throw JanetError.runFailed(detail)
        }
        return result
    }

    /// Call a Janet function (or cfunction) value with a single string
    /// argument.
    ///
    /// Uses `janet_pcall` via a one-time-compiled thunk `(fn [f x] (f x))`, so
    /// both bytecode closures and bare C functions (e.g. `json/valid?`) can be
    /// invoked. No per-call parsing or compilation happens.
    private var _callThunk: Janet?

    public func callWithString(_ fn: Janet, input: String) throws -> Janet {
        let thunk = try callThunk()
        var out = Janet()
        var args: [Janet] = [fn, janet_wrap_string(janet_cstring(input))]
        var sig = JANET_SIGNAL_OK
        args.withUnsafeMutableBufferPointer { buf in
            sig = janet_pcall(thunk, Int32(buf.count), buf.baseAddress!, &out, nil)
        }
        guard sig == JANET_SIGNAL_OK else {
            throw JanetError.runFailed("function call")
        }
        return out
    }

    private func callThunk() throws -> UnsafeMutablePointer<JanetFunction>? {
        if let t = _callThunk, janet_checktype(t, JANET_FUNCTION) != 0 {
            return janet_unwrap_function(t)
        }
        let v = try eval(source: "(fn [f x] (f x))")
        janet_gcroot(v) // keep the thunk alive across GCs
        _callThunk = v
        return janet_unwrap_function(v)
    }

    public func match(source: String, input: String) throws -> Bool {
        let wrapped = """
        (let [input \(JanetVM.quoteString(input))]
          \(source))
        """
        let result = try eval(source: wrapped)
        return janet_truthy(result) != 0
    }

    public func transform(source: String, input: String) throws -> String {
        let wrapped = """
        (let [input \(JanetVM.quoteString(input))]
          \(source))
        """
        let result = try eval(source: wrapped)
        guard let ptr = janet_unwrap_string(result) else {
            throw JanetError.unexpectedReturnType
        }
        return String(cString: ptr)
    }

    /// Produce a Janet double-quoted string literal for `s`, escaping every
    /// character that could break out of the literal or inject code.
    public nonisolated static func quoteString(_ s: String) -> String {
        var out = "\""
        for scalar in s.unicodeScalars {
            switch scalar {
            case "\\": out += "\\\\"
            case "\"": out += "\\\""
            case "\n": out += "\\n"
            case "\r": out += "\\r"
            case "\t": out += "\\t"
            case "\0": out += "\\0"
            default:
                if scalar.value < 0x20 || scalar.value == 0x7f {
                    out += String(format: "\\x%02X", scalar.value)
                } else {
                    out.append(Character(scalar))
                }
            }
        }
        out += "\""
        return out
    }

    /// Best-effort string description of a Janet value, for error messages.
    /// Returns "<unknown>" if the value can't be described.
    nonisolated static func describe(_ v: Janet) -> String {
        guard let s = janet_to_string(v) else { return "<unknown>" }
        return String(cString: s)
    }
}

@_silgen_name("clipfmt_defrule_cfun")
func clipfmt_defrule_cfun(_ env: UnsafeMutablePointer<JanetTable>?)
