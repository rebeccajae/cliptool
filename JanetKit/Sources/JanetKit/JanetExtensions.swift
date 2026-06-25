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

@_cdecl("swift_xml_valid")
func swiftXmlValid(argc: Int32, argv: UnsafePointer<Janet>) -> Janet {
    guard argc == 1,
          let ptr = janet_unwrap_string(argv[0]) else {
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
func swiftXmlPretty(argc: Int32, argv: UnsafePointer<Janet>) -> Janet {
    guard argc == 1,
          let ptr = janet_unwrap_string(argv[0]) else {
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
func swiftBase64Decode(argc: Int32, argv: UnsafePointer<Janet>) -> Janet {
    guard argc == 1,
          let ptr = janet_unwrap_string(argv[0]) else {
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

