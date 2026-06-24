import Testing
import JanetKit

@Suite("JanetVM")
struct JanetKitTests {
    @Test func jsonValidMatcher() throws {
        let vm = try JanetVM()
        let result = try vm.match(source: "(json/valid? input)", input: "{\"foo\": 1}")
        #expect(result == true)
    }

    @Test func jsonInvalidMatcher() throws {
        let vm = try JanetVM()
        let result = try vm.match(source: "(json/valid? input)", input: "not json")
        #expect(result == false)
    }

    @Test func jsonPrettyTransform() throws {
        let vm = try JanetVM()
        let result = try vm.transform(source: "(json/pretty input)", input: "{\"foo\":1}")
        #expect(result.contains("foo"))
    }
}

