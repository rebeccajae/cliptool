import Testing
import Foundation
import CJanet
import JanetKit

// MARK: - Stub for defrule callback

struct StoredRule {
    let mode: Int32
    let name: String
    let matcher: Janet
    let transform: Janet
}

nonisolated(unsafe) var collectedRules: [StoredRule] = []

@_cdecl("clipfmt_add_rule")
func clipfmt_add_rule(mode: Int32, name: UnsafePointer<CChar>, matcher: Janet, transform: Janet) {
    collectedRules.append(StoredRule(
        mode: mode,
        name: String(cString: name),
        matcher: matcher,
        transform: transform
    ))
}

extension Janet {
    var asBool: Bool { janet_truthy(self) != 0 }
    var asString: String? {
        guard let ptr = janet_unwrap_string(self) else { return nil }
        return String(cString: ptr)
    }
}

// MARK: - JSON

@Suite("json") @MainActor struct JsonTests {
    @Test func valid() throws {
        let vm = try JanetVM()
        #expect(try vm.match(source: "(json/valid? input)", input: #"{"a":1}"#) == true)
    }
    @Test func invalid() throws {
        let vm = try JanetVM()
        #expect(try vm.match(source: "(json/valid? input)", input: "nope") == false)
    }
    @Test func pretty() throws {
        let vm = try JanetVM()
        let r = try vm.transform(source: "(json/pretty input)", input: #"{"b":2}"#)
        #expect(r.contains("2"))
    }
}

// MARK: - XML

@Suite("xml") @MainActor struct XmlTests {
    @Test func valid() throws {
        let vm = try JanetVM()
        #expect(try vm.match(source: "(xml/valid? input)", input: "<root/>") == true)
    }
    @Test func invalid() throws {
        let vm = try JanetVM()
        #expect(try vm.match(source: "(xml/valid? input)", input: "nope") == false)
    }
    @Test func pretty() throws {
        let vm = try JanetVM()
        let r = try vm.transform(source: "(xml/pretty input)", input: "<r><a/></r>")
        #expect(r.contains("\n"))
    }
}

// MARK: - Base64

@Suite("base64") @MainActor struct Base64Tests {
    @Test func decode() throws {
        let vm = try JanetVM()
        #expect(try vm.transform(source: "(base64/decode input)", input: "aGVsbG8=") == "hello")
    }
}

// MARK: - callWithString

@Suite("callWithString") @MainActor struct CallTests {
    @Test func matcher() throws {
        let vm = try JanetVM()
        _ = try vm.eval(source: #"(def p (fn [s] (string/has-prefix? "GET" s)))"#)
        let fn = try vm.eval(source: "p")
        #expect(try vm.callWithString(fn, input: "GET /").asBool == true)
        #expect(try vm.callWithString(fn, input: "POST /").asBool == false)
    }
    @Test func transform() throws {
        let vm = try JanetVM()
        _ = try vm.eval(source: #"(def t (fn [s] (string/ascii-upper s)))"#)
        let fn = try vm.eval(source: "t")
        #expect(try vm.callWithString(fn, input: "hi").asString == "HI")
    }
    @Test func cfun() throws {
        let vm = try JanetVM()
        let fn = try vm.eval(source: "json/valid?")
        #expect(try vm.callWithString(fn, input: #"{"a":1}"#).asBool == true)
        #expect(try vm.callWithString(fn, input: "nope").asBool == false)
    }
}

// MARK: - defrule

@Suite("defrule") @MainActor struct DefruleTests {
    @Test func registers() throws {
        collectedRules = []
        let vm = try JanetVM()
        _ = try vm.eval(source: #"(defrule "J" :always json/valid? json/pretty)"#)
        #expect(collectedRules.count == 1)
        #expect(collectedRules[0].name == "J")
        #expect(collectedRules[0].mode == 0)
    }
    @Test func callable() throws {
        collectedRules = []
        let vm = try JanetVM()
        _ = try vm.eval(source: #"(defrule "U" :always (fn [s] (string/ascii-upper s)) (fn [s] (string/ascii-upper s)))"#)
        #expect(collectedRules.count == 1)
        #expect(try vm.callWithString(collectedRules[0].matcher, input: "x").asBool == true)
        #expect(try vm.callWithString(collectedRules[0].transform, input: "x").asString == "X")
    }

    @Test func nonStringNameRaisesCatchableError() throws {
        // A non-string name used to dereference a mistyped union and crash the
        // host process. It must instead raise a catchable Janet error (which
        // ConfigWatcher surfaces in the menu) and register nothing.
        collectedRules = []
        let vm = try JanetVM()
        #expect(throws: JanetError.self) {
            _ = try vm.eval(source: "(defrule 123 :always json/valid? json/pretty)")
        }
        #expect(collectedRules.isEmpty)
    }

    @Test func nonKeywordTriggerRaisesCatchableError() throws {
        // A non-keyword trigger (e.g. a string) must raise rather than crash.
        collectedRules = []
        let vm = try JanetVM()
        #expect(throws: JanetError.self) {
            _ = try vm.eval(source: #"(defrule "X" "always" json/valid? json/pretty)"#)
        }
        #expect(collectedRules.isEmpty)
    }
}

// MARK: - Integration

@Suite("integration") @MainActor struct IntegrationTests {
    @Test func demoConfig() throws {
        collectedRules = []
        let vm = try JanetVM()
        _ = try vm.eval(source: #"""
        (defn has-jwt-header? [s] (string/has-prefix? "eyJ" (string/trim s)))
        (defrule "Format JSON" :always json/valid? json/pretty)
        (defrule "Decode JWT" :always has-jwt-header? (fn [s] (string/ascii-upper s)))
        """#)
        #expect(collectedRules.count == 2)

        // JSON matcher + transform
        #expect(try vm.callWithString(collectedRules[0].matcher, input: #"{"a":1}"#).asBool == true)
        let pretty = try vm.callWithString(collectedRules[0].transform, input: #"{"b":2}"#)
        #expect(try #require(pretty.asString).contains("2"))

        // JWT matcher
        #expect(try vm.callWithString(collectedRules[1].matcher, input: "eyJ.x.y").asBool == true)
        #expect(try vm.callWithString(collectedRules[1].matcher, input: "nope").asBool == false)
    }
}

// MARK: - Error messages

@Suite("errorMessages") @MainActor struct ErrorMessageTests {
    @Test func evalErrorIncludesJanetMessage() throws {
        let vm = try JanetVM()
        do {
            _ = try vm.eval(source: "(+ 1 \"a\")")
            Issue.record("should have thrown")
        } catch let JanetError.runFailed(detail) {
            #expect(detail.contains("could not find method"))
        } catch {
            Issue.record("unexpected error type: \(error)")
        }
    }

    @Test func arityErrorIncludesJanetMessage() throws {
        let vm = try JanetVM()
        do {
            _ = try vm.eval(source: "(defrule \"X\" :always)")
            Issue.record("should have thrown")
        } catch let JanetError.runFailed(detail) {
            #expect(detail.contains("arity"))
        } catch {
            Issue.record("unexpected error type: \(error)")
        }
    }
}

// MARK: - VM isolation

@Suite("vmIsolation") @MainActor struct VMIsolationTests {
    @Test func topLevelDefDoesNotLeakBetweenInstances() throws {
        let vm1 = try JanetVM()
        _ = try vm1.eval(source: "(def secret 42)")

        // A fresh VM must NOT see `secret`: each instance gets its own user
        // environment. (Regression for the old bug where eval reused the shared
        // global core env, leaking defs across instances.)
        let vm2 = try JanetVM()
        #expect(throws: JanetError.self) {
            _ = try vm2.eval(source: "secret")
        }
    }

    @Test func coreBindingsResolveInEveryInstance() throws {
        // Core bindings (our registered cfunctions) must still resolve in a
        // fresh instance via the env prototype chain.
        let vm = try JanetVM()
        let result = try vm.eval(source: "(json/valid? \"{\\\"a\\\":1}\")")
        #expect(janet_truthy(result) != 0)
    }
}

// MARK: - url / jwt helpers

@Suite("helpers") @MainActor struct HelperTests {
    @Test func percentDecode() throws {
        let vm = try JanetVM()
        let r = try vm.transform(source: "(string/percent-decode input)", input: "a%20b%2Bc+d")
        #expect(r == "a b+c d")
    }

    @Test func jwtBody() throws {
        let vm = try JanetVM()
        // header.payload.sig where payload = {"sub":"123"} base64url-encoded.
        let payload = Data("{\"sub\":\"123\"}".utf8)
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        let jwt = "header.\(payload).sig"
        let r = try vm.transform(source: "(extract-jwt-body input)", input: jwt)
        #expect(r == "{\"sub\":\"123\"}")
    }

    @Test func jwtBodyRejectsNonJwt() throws {
        let vm = try JanetVM()
        // Not enough segments -> nil -> transform throws.
        #expect(throws: JanetError.self) {
            _ = try vm.transform(source: "(extract-jwt-body input)", input: "no-dots-here")
        }
    }
}
