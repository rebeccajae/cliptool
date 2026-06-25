import AppKit
import JanetKit

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var monitor: ClipboardMonitor!
    private var snoozeState: SnoozeState = .active
    private var configWatcher: ConfigWatcher!
    private var rules: [RegisteredRule] = []
    private var janet: JanetVM!
    private var isShowingMenu = false
    private var cachedMenu: NSMenu?
    private var lastAlways: [RegisteredRule] = []
    private var lastManual: [RegisteredRule] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.action = #selector(handleClick)
        statusItem.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        statusItem.button?.target = self
        monitor = ClipboardMonitor { [weak self] in
            self?.clipboardDidChange()
        }
        janet = try! JanetVM()
        configWatcher = ConfigWatcher(janet: janet) { [weak self] rules in
            self?.rules = rules
            self?.clipboardDidChange()
        }
        configWatcher.start()
        monitor.start()
        updateIcon()
    }

    @objc private func handleClick(_ sender: NSStatusBarButton) {
        guard !isShowingMenu else { return }
        let event = NSApp.currentEvent!

        if event.type == .leftMouseUp, lastAlways.count == 1, snoozeState.isActive {
            if let output = RuleEngine.apply(lastAlways[0], input: currentInput()) {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(output, forType: .string)
                updateIcon()
            }
        } else {
            if cachedMenu == nil {
                cachedMenu = StatusMenuBuilder.build(
                    always: lastAlways,
                    manual: lastManual,
                    snoozeState: snoozeState,
                    onApply: { [weak self] rule in
                        guard let input = ClipboardMonitor.currentStringValue(),
                              let output = RuleEngine.apply(rule, input: input) else { return }
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(output, forType: .string)
                        self?.updateIcon()
                    },
                    onSnooze: { [weak self] option in self?.applySnooze(option) },
                    onQuit: { NSApp.terminate(nil) }
                )
            }
            isShowingMenu = true
            statusItem.menu = cachedMenu
            statusItem.button?.performClick(nil)
            statusItem.menu = nil
            isShowingMenu = false
        }
    }

    private func clipboardDidChange() {
        guard snoozeState.isActive else {
            snoozeState.recordSkip()
            return
        }
        updateIcon()
    }

    private func currentInput() -> String {
        ClipboardMonitor.currentStringValue() ?? ""
    }

    private func updateIcon() {
        guard let button = statusItem.button else { return }
        (lastAlways, lastManual) = RuleEngine.evaluate(rules, input: currentInput())
        cachedMenu = nil
        let hasMatch = !lastAlways.isEmpty || !lastManual.isEmpty
        button.image = NSImage(systemSymbolName: hasMatch ? "doc.badge.arrow.up" : "doc", accessibilityDescription: nil)
    }

    private func applySnooze(_ option: SnoozeOption) {
        switch option {
        case .minutes(let n) where n == 0:
            snoozeState = .active
        case .minutes(let n):
            snoozeState = .snoozed(option, skipped: 0)
            DispatchQueue.main.asyncAfter(deadline: .now() + TimeInterval(n * 60)) { [weak self] in
                guard let self, case .snoozed = self.snoozeState else { return }
                self.snoozeState = .active
                self.updateIcon()
            }
        case .off:
            snoozeState = .off
        }
        updateIcon()
    }
}
