import AppKit
import JanetKit

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var monitor: ClipboardMonitor!
    private var snoozeState: SnoozeState = .active
    private var configWatcher: ConfigWatcher!
    private var rules: [RegisteredRule] = []
    private var janet: JanetVM!
    private var lastAlways: [RegisteredRule] = []
    private var lastManual: [RegisteredRule] = []
    private var lastError: String?
    // Guards against the performClick menu-show idiom re-entering handleClick.
    private var isShowingMenu = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.action = #selector(handleClick)
        statusItem.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        statusItem.button?.target = self
        monitor = ClipboardMonitor { [weak self] in
            self?.clipboardDidChange()
        }
        do {
            janet = try JanetVM()
        } catch {
            fatalError("clipfmt: failed to initialise Janet runtime: \(error)")
        }
        configWatcher = ConfigWatcher(janet: janet) { [weak self] rules in
            self?.rules = rules
            self?.clipboardDidChange()
        } onError: { [weak self] message in
            self?.lastError = message
            self?.clipboardDidChange()
        }
        configWatcher.start()
        monitor.start()
        evaluateRules()
        renderIcon()
    }

    @objc private func handleClick(_ sender: NSStatusBarButton) {
        guard !isShowingMenu, let event = NSApp.currentEvent else { return }

        // Left-click with exactly one auto rule: apply immediately. If the
        // transform fails, fall through to the menu so the click isn't
        // silently swallowed.
        if event.type == .leftMouseUp, lastAlways.count == 1, snoozeState.isActive {
            if let output = RuleEngine.apply(lastAlways[0], input: currentInput(), vm: janet) {
                writeClipboard(output)
                return
            }
        }

        let menu = StatusMenuBuilder.build(
            always: lastAlways,
            manual: lastManual,
            snoozeState: snoozeState,
            error: lastError,
            onApply: { [weak self] rule in
                guard let self,
                      let input = ClipboardMonitor.currentStringValue(),
                      let output = RuleEngine.apply(rule, input: input, vm: self.janet) else { return }
                self.writeClipboard(output)
            },
            onSnooze: { [weak self] option in self?.applySnooze(option) },
            onQuit: { NSApp.terminate(nil) }
        )
        isShowingMenu = true
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
        isShowingMenu = false
    }

    private func writeClipboard(_ string: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
        // Update immediately rather than waiting for the next poll.
        evaluateRules()
        renderIcon()
    }

    private func clipboardDidChange() {
        guard snoozeState.isActive else {
            snoozeState.recordSkip()
            return
        }
        evaluateRules()
        renderIcon()
    }

    private func currentInput() -> String {
        ClipboardMonitor.currentStringValue() ?? ""
    }

    /// Re-run every matcher against the current clipboard contents and cache
    /// the result. This is the only place matchers run.
    private func evaluateRules() {
        (lastAlways, lastManual) = RuleEngine.evaluate(rules, input: currentInput(), vm: janet)
    }

    /// Render the status icon from the most recent evaluation. Does not touch
    /// the clipboard and does not run matchers.
    private func renderIcon() {
        guard let button = statusItem.button else { return }
        let hasMatch = !lastAlways.isEmpty || !lastManual.isEmpty
        button.image = NSImage(systemSymbolName: hasMatch ? "doc.badge.arrow.up" : "doc", accessibilityDescription: nil)
    }

    private func applySnooze(_ option: SnoozeOption) {
        switch option {
        case .resume:
            snoozeState = .active
        case .minutes(let n):
            snoozeState = .snoozed(option, skipped: 0)
            DispatchQueue.main.asyncAfter(deadline: .now() + TimeInterval(n * 60)) { [weak self] in
                guard let self, case .snoozed = self.snoozeState else { return }
                self.snoozeState = .active
                // The clipboard may have changed while we were snoozed (those
                // changes were skipped, not evaluated), so re-evaluate now.
                self.evaluateRules()
                self.renderIcon()
            }
        case .off:
            snoozeState = .off
        }
        renderIcon()
    }
}
