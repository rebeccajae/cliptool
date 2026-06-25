import Testing
import Foundation
import JanetKit

@Suite("ConfigWatcher") @MainActor struct ConfigWatcherTests {
    private func writeConfig(_ content: String) throws -> String {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("clipfmt-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let path = dir.appendingPathComponent("config.janet").path
        try content.write(toFile: path, atomically: true, encoding: .utf8)
        return path
    }

    private func rewrite(_ path: String, _ content: String) throws {
        try content.write(toFile: path, atomically: true, encoding: .utf8)
    }

    @Test func loadsGoodConfig() throws {
        let path = try writeConfig(#"""
        (defrule "Upper" :always (fn [s] true) (fn [s] (string/ascii-upper s)))
        """#)
        let vm = try JanetVM()
        var received: [RegisteredRule] = []
        var errors: [String] = []
        let watcher = ConfigWatcher(path: path, janet: vm,
                                    onChange: { received = $0 },
                                    onError: { errors.append($0) })
        watcher.start()
        #expect(received.count == 1)
        #expect(received[0].name == "Upper")
        #expect(errors.isEmpty)
        watcher.stop()
        RuleStorage.clear()
    }

    @Test func brokenEditKeepsLastGoodRules() throws {
        let good = #"""
        (defrule "Good" :always (fn [s] true) (fn [s] s))
        """#
        let broken = #"""
        (defrule "Good" :always (fn [s] true) (fn [s] s))
        (defrule :always "Bad" not-a-function not-a-function)
        """#
        let path = try writeConfig(good)
        let vm = try JanetVM()
        var received: [RegisteredRule] = []
        var errors: [String] = []
        let watcher = ConfigWatcher(path: path, janet: vm,
                                    onChange: { received = $0 },
                                    onError: { errors.append($0) })
        watcher.start()
        #expect(received.count == 1)
        #expect(received[0].name == "Good")

        // Overwrite with a broken config. The partial load (first defrule
        // succeeds, second throws) must NOT replace the good ruleset.
        try rewrite(path, broken)
        watcher.load() // simulate the reload that handleFileEvent triggers

        // After the broken reload, the good rule must still be present and the
        // partial second rule must NOT have leaked in.
        #expect(received.count == 1)
        #expect(received[0].name == "Good")
        #expect(!errors.isEmpty)
        watcher.stop()
        RuleStorage.clear()
    }

    @Test func validRewriteReplacesRuleset() throws {
        let first = #"""
        (defrule "First" :always (fn [s] true) (fn [s] s))
        """#
        let second = #"""
        (defrule "Second" :always (fn [s] true) (fn [s] s))
        """#
        let path = try writeConfig(first)
        let vm = try JanetVM()
        var received: [RegisteredRule] = []
        let watcher = ConfigWatcher(path: path, janet: vm,
                                    onChange: { received = $0 },
                                    onError: { _ in })
        watcher.start()
        #expect(received.count == 1)
        #expect(received[0].name == "First")

        // A valid rewrite must actually replace the ruleset, not append or
        // keep the old one. (Regression for the reload path actually picking
        // up new content.)
        try rewrite(path, second)
        watcher.load()

        #expect(received.count == 1)
        #expect(received[0].name == "Second")
        watcher.stop()
        RuleStorage.clear()
    }

    @Test func missingAtStartLoadsWhenAppears() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("clipfmt-missing-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let path = dir.appendingPathComponent("config.janet").path

        let vm = try JanetVM()
        var received: [RegisteredRule] = []
        let watcher = ConfigWatcher(path: path, janet: vm,
                                    onChange: { received = $0 },
                                    onError: { _ in })
        watcher.start()
        // No file yet: nothing loaded.
        #expect(received.isEmpty)

        // Create the file and wait for the retry timer (2s) to pick it up.
        try #"""
        (defrule "Late" :always (fn [s] true) (fn [s] s))
        """#.write(toFile: path, atomically: true, encoding: .utf8)
        try await Task.sleep(for: .seconds(3))

        #expect(received.count == 1)
        #expect(received[0].name == "Late")
        watcher.stop()
        RuleStorage.clear()
    }
}
