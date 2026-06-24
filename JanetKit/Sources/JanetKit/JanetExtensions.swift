import CJanet
import Foundation

@_cdecl("swift_json_valid")
func swiftJsonValid(argc: Int32, argv: UnsafePointer<Janet>) -> Janet {
    guard argc == 1,
          let ptr = janet_unwrap_string(argv[0]) else {
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
func swiftJsonPretty(argc: Int32, argv: UnsafePointer<Janet>) -> Janet {
    guard argc == 1,
          let ptr = janet_unwrap_string(argv[0]) else {
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

