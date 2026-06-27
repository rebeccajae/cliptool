import Foundation
import CJanet
import JanetKit

/// Loads the Janet config and reloads it whenever the file changes on disk.
///
/// All Janet work happens on the main thread (the `@MainActor`), matching
/// `JanetVM`'s threading contract.
@MainActor
final class ConfigWatcher {
    private let path: String
    private var source: DispatchSourceFileSystemObject?
    private var retryTimer: DispatchSourceTimer?
    private let janet: JanetVM
    private let onChange: ([RegisteredRule]) -> Void
    private let onError: (String) -> Void

    init(
        path: String = ("~/.config/clipfmt/config.janet" as NSString).expandingTildeInPath,
        janet: JanetVM,
        onChange: @escaping ([RegisteredRule]) -> Void,
        onError: @escaping (String) -> Void = { print("clipfmt: \($0)") }
    ) {
        self.path = path
        self.janet = janet
        self.onChange = onChange
        self.onError = onError
    }

    func start() {
        guard FileManager.default.fileExists(atPath: path) else {
            // Config not present yet (e.g. first run). Poll until it appears,
            // then install the real watcher. Without this the watcher would
            // silently give up forever at launch.
            scheduleMissingFileRetry()
            return
        }
        load()
        installWatcher()
    }

    func stop() {
        source?.cancel()
        source = nil
        retryTimer?.cancel()
        retryTimer = nil
    }

    private func scheduleMissingFileRetry() {
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + .seconds(2), repeating: .seconds(2))
        timer.setEventHandler { [weak self] in
            guard let self else { return }
            guard FileManager.default.fileExists(atPath: self.path) else { return }
            self.retryTimer?.cancel()
            self.retryTimer = nil
            self.load()
            self.installWatcher()
        }
        timer.resume()
        retryTimer = timer
    }

    /// Watch the config file. Editors commonly save by writing a temp file and
    /// renaming it over the original, which replaces the inode the watched fd
    /// points at — after which `.write` never fires again. So we watch for
    /// `.write`, `.delete`, and `.rename`, and on *any* event we re-arm the
    /// watcher (re-open by path) after a short debounce so the new inode is
    /// tracked.
    private func installWatcher() {
        let fd = open(path, O_EVTONLY)
        guard fd >= 0 else {
            let reason = String(cString: strerror(errno))
            onError("could not watch config at \(path): \(reason)")
            return
        }
        let src = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .delete, .rename],
            queue: .main
        )
        src.setEventHandler { [weak self] in
            self?.handleFileEvent()
        }
        src.setCancelHandler { close(fd) }
        src.resume()
        source = src
    }

    /// Debounce file events (editors that save-by-rename can fire several in
    /// quick succession) then reload and re-arm.
    private var reloadScheduled = false
    private func handleFileEvent() {
        guard !reloadScheduled else { return }
        reloadScheduled = true
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(150)) { [weak self] in
            guard let self else { return }
            self.reloadScheduled = false
            // Re-arm first so we track the (possibly new) inode, then reload.
            self.source?.cancel()
            self.source = nil
            self.load()
            self.installWatcher()
        }
    }

    /// Reload the config from disk. Internal so tests can drive reloads
    /// directly without waiting for file-system event timing.
    func load() {
        guard let source = try? String(contentsOfFile: path, encoding: .utf8) else {
            onError("failed to read config file at \(path)")
            onChange(RuleStorage.rules)
            return
        }
        // Snapshot the current good ruleset so we can restore it if this eval
        // fails partway through (which would leave RuleStorage holding a
        // *partial* new ruleset).
        let snapshot = RuleStorage.rules
        RuleStorage.clear()
        // Re-root the snapshot so a GC during eval can't collect the values
        // before we decide whether to restore them.
        for rule in snapshot {
            janet_gcroot(rule.matcher)
            janet_gcroot(rule.transform)
        }
        do {
            _ = try janet.eval(source: source)
            // Success: the new rules are now in RuleStorage. Drop the old
            // snapshot (now superseded).
            for rule in snapshot {
                _ = janet_gcunroot(rule.matcher)
                _ = janet_gcunroot(rule.transform)
            }
            onChange(RuleStorage.rules)
        } catch {
            // Eval failed partway: drop the partial new rules and restore the
            // last good set so the app keeps working with what it had.
            RuleStorage.clear()
            RuleStorage.rules = snapshot  // already re-rooted above
            onError("failed to load config: \(error)")
            onChange(RuleStorage.rules)
        }
    }
}
