import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var monitor: ClipboardMonitor!
    private var snoozeState: SnoozeState = .active
    private var cachedMenu: NSMenu?
    private var configWatcher: ConfigWatcher!
    private var rules: [RuleConfig] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.menu = nil
        statusItem.button?.action = #selector(handleClick)
        statusItem.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        statusItem.button?.target = self
        monitor = ClipboardMonitor { [weak self] in
            self?.clipboardDidChange()
        }
        updateIcon()
        configWatcher = ConfigWatcher { [weak self] rules in
            self?.rules = rules
            self?.clipboardDidChange()
        }
        configWatcher.start()
        monitor.start()
        cachedMenu = buildMenu()
    }
    
    @objc private func handleClick(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent!
        statusItem.menu = nil

        if event.type == .rightMouseUp {
            showMenu(cachedMenu ?? buildMenu())
        } else {
            let input = ClipboardMonitor.currentStringValue() ?? ""
            let (always, _) = RuleEngine.evaluate(rules, input: input)
            if always.count == 1 && snoozeState.isActive {
                if let output = RuleEngine.apply(always[0], input: input) {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(output, forType: .string)
                    updateIcon()
                }
            } else {
                showMenu(cachedMenu ?? buildMenu())
            }
        }
    }

    private func showMenu(_ menu: NSMenu) {
        statusItem.menu = menu
        DispatchQueue.main.async {
            self.statusItem.button?.performClick(nil)
        }
    }

    private func clipboardDidChange() {
        guard snoozeState.isActive else {
            snoozeState.recordSkip()
            return
        }
        let input = ClipboardMonitor.currentStringValue() ?? ""
        let (always, manual) = RuleEngine.evaluate(rules, input: input)
        cachedMenu = always.count == 1 ? nil : buildMenu()
        updateIcon()
    }

    private func updateIcon() {
        guard let button = statusItem.button else { return }
        let input = ClipboardMonitor.currentStringValue() ?? ""
        let (always, manual) = RuleEngine.evaluate(rules, input: input)
        let hasMatch = !always.isEmpty || !manual.isEmpty
        button.image = NSImage(systemSymbolName: hasMatch ? "doc.badge.arrow.up" : "doc", accessibilityDescription: nil)
    }

    private func buildMenu() -> NSMenu {
        let input = ClipboardMonitor.currentStringValue() ?? ""
        let (always, manual) = RuleEngine.evaluate(rules, input: input)
        return StatusMenuBuilder.build(
            always: always,
            manual: manual,
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

extension AppDelegate: NSMenuDelegate {
    func menuDidClose(_ menu: NSMenu) {
        statusItem.menu = nil
    }
}
