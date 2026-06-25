import CJanet
import Foundation

// These helpers are `@_cdecl` so Janet can call them as C functions, but they
// are registered with Janet from Swift (see `clipfmtRegisterSwiftExtensions`
// below). Taking their addresses in Swift is what prevents the Release
// whole-module optimizer from dead-stripping them.

@_cdecl("swift_json_valid")
func swiftJsonValid(argc: Int32, argv: UnsafeMutablePointer<Janet>?) -> Janet {
    guard argc == 1, let argv, let ptr = janet_unwrap_string(argv[0]) else {
        return janet_wrap_boolean(0)
    }
    let str = String(cString: ptr)
    guard let data = str.data(using: .utf8),
          let _ = try? JSONSerialization.jsonObject(with: data) else {
        return janet_wrap_boolean(0)
    }
    return janet_wrap_boolean(1)
}

@_cdecl("swift_json_pretty")
func swiftJsonPretty(argc: Int32, argv: UnsafeMutablePointer<Janet>?) -> Janet {
    guard argc == 1, let argv, let ptr = janet_unwrap_string(argv[0]) else {
        return janet_wrap_nil()
    }
    let str = String(cString: ptr)
    guard let data = str.data(using: .utf8),
          let obj = try? JSONSerialization.jsonObject(with: data),
          let pretty = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]),
          let result = String(data: pretty, encoding: .utf8) else {
        return janet_wrap_nil()
    }
    let janetStr = result.withCString { janet_cstring($0) }
    return janet_wrap_string(janetStr)
}

@_cdecl("swift_xml_valid")
func swiftXmlValid(argc: Int32, argv: UnsafeMutablePointer<Janet>?) -> Janet {
    guard argc == 1, let argv, let ptr = janet_unwrap_string(argv[0]) else {
        return janet_wrap_boolean(0)
    }
    let str = String(cString: ptr)
    guard let data = str.data(using: .utf8),
          (try? XMLDocument(data: data)) != nil else {
        return janet_wrap_boolean(0)
    }
    return janet_wrap_boolean(1)
}

@_cdecl("swift_xml_pretty")
func swiftXmlPretty(argc: Int32, argv: UnsafeMutablePointer<Janet>?) -> Janet {
    guard argc == 1, let argv, let ptr = janet_unwrap_string(argv[0]) else {
        return janet_wrap_nil()
    }
    let str = String(cString: ptr)
    guard let data = str.data(using: .utf8),
          let xml = try? XMLDocument(data: data) else {
        return janet_wrap_nil()
    }
    let pretty = xml.xmlString(options: [.nodePrettyPrint])
    let janetStr = pretty.withCString { janet_cstring($0) }
    return janet_wrap_string(janetStr)
}

@_cdecl("swift_base64_decode")
func swiftBase64Decode(argc: Int32, argv: UnsafeMutablePointer<Janet>?) -> Janet {
    guard argc == 1, let argv, let ptr = janet_unwrap_string(argv[0]) else {
        return janet_wrap_nil()
    }
    let str = String(cString: ptr)
    guard let data = Data(base64Encoded: str),
          let result = String(data: data, encoding: .utf8) else {
        return janet_wrap_nil()
    }
    let janetStr = result.withCString { janet_cstring($0) }
    return janet_wrap_string(janetStr)
}

@_cdecl("swift_percent_decode")
func swiftPercentDecode(argc: Int32, argv: UnsafeMutablePointer<Janet>?) -> Janet {
    guard argc == 1, let argv, let ptr = janet_unwrap_string(argv[0]) else {
        return janet_wrap_nil()
    }
    let str = String(cString: ptr)
    // URL percent-decode: turn %XX into the byte, and '+' into space (the
    // classic application/x-www-form-urlencoded convention).
    var out = [UInt8]()
    var bytes = Array(str.utf8)
    var i = 0
    while i < bytes.count {
        let b = bytes[i]
        if b == 0x2B { // '+'
            out.append(0x20)
            i += 1
        } else if b == 0x25, i + 2 < bytes.count { // '%'
            if let hi = hexDigit(bytes[i + 1]), let lo = hexDigit(bytes[i + 2]) {
                out.append(hi << 4 | lo)
                i += 3
            } else {
                out.append(b)
                i += 1
            }
        } else {
            out.append(b)
            i += 1
        }
    }
    guard let result = String(bytes: out, encoding: .utf8) else {
        return janet_wrap_nil()
    }
    return result.withCString { janet_wrap_string(janet_cstring($0)) }
}

private func hexDigit(_ b: UInt8) -> UInt8? {
    switch b {
    case 0x30...0x39: return b - 0x30        // 0-9
    case 0x41...0x46: return b - 0x41 + 10   // A-F
    case 0x61...0x66: return b - 0x61 + 10   // a-f
    default: return nil
    }
}

@_cdecl("swift_jwt_body")
func swiftJwtBody(argc: Int32, argv: UnsafeMutablePointer<Janet>?) -> Janet {
    guard argc == 1, let argv, let ptr = janet_unwrap_string(argv[0]) else {
        return janet_wrap_nil()
    }
    let str = String(cString: ptr)
    // A JWT is three base64url segments separated by '.': header.payload.sig.
    let parts = str.split(separator: ".")
    guard parts.count >= 2 else { return janet_wrap_nil() }
    let payload = String(parts[1])
    // base64url -> base64: replace URL-safe chars and pad.
    var b64 = payload
        .replacingOccurrences(of: "-", with: "+")
        .replacingOccurrences(of: "_", with: "/")
    while b64.count % 4 != 0 { b64 += "=" }
    guard let data = Data(base64Encoded: b64),
          let result = String(data: data, encoding: .utf8) else {
        return janet_wrap_nil()
    }
    return result.withCString { janet_wrap_string(janet_cstring($0)) }
}

/// Register the Swift-backed Janet functions (json, xml, base64) into `env`.
///
/// Building the `JanetReg` array here — and taking the address of each
/// `@_cdecl` function as a `JanetCFunction` — is what keeps those symbols from
/// being dead-stripped in Release builds. (The C side only references them
/// indirectly, which the Swift whole-module optimizer cannot see.)
@_cdecl("clipfmt_register_swift_extensions")
func clipfmtRegisterSwiftExtensions(_ env: UnsafeMutablePointer<JanetTable>?) {
    // `janet_def` interns the name and copies the docstring during the call, so
    // the Swift string literals (valid for the call's duration) are sufficient.
    janet_def(env, "json/valid?", janet_wrap_cfunction(swiftJsonValid),
              "(json/valid? str)\n\nReturns true if str is valid JSON.")
    janet_def(env, "json/pretty", janet_wrap_cfunction(swiftJsonPretty),
              "(json/pretty str)\n\nReturns pretty-printed JSON string.")
    janet_def(env, "xml/valid?", janet_wrap_cfunction(swiftXmlValid),
              "(xml/valid? str)\n\nReturns true if str is valid XML.")
    janet_def(env, "xml/pretty", janet_wrap_cfunction(swiftXmlPretty),
              "(xml/pretty str)\n\nReturns pretty-printed XML string.")
    janet_def(env, "base64/decode", janet_wrap_cfunction(swiftBase64Decode),
              "(base64/decode str)\n\nBase64-decodes str and returns the decoded UTF-8 string.")
    janet_def(env, "string/percent-decode", janet_wrap_cfunction(swiftPercentDecode),
              "(string/percent-decode str)\n\nURL-percent-decodes str (also turns '+' into space).")
    janet_def(env, "extract-jwt-body", janet_wrap_cfunction(swiftJwtBody),
              "(extract-jwt-body str)\n\nExtracts and base64url-decodes the payload segment of a JWT, returning it as a string.")
}
