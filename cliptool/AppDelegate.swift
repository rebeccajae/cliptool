import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var monitor: ClipboardMonitor!
    private var snoozeState: SnoozeState = .active
    private var cachedMenu: NSMenu?

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
        monitor.start()
        cachedMenu = buildMenu()
    }
    
    @objc private func handleClick(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent!
        statusItem.menu = nil

        if event.type == .rightMouseUp {
            showMenu(cachedMenu ?? buildMenu())
        } else {
            let hasJSON = ClipboardMonitor.currentStringValue()
                .flatMap { JSONFormatter.format($0) } != nil
            if hasJSON && snoozeState.isActive {
                applyTransform()
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
        let hasJSON = ClipboardMonitor.currentStringValue()
            .flatMap { JSONFormatter.format($0) } != nil
        cachedMenu = hasJSON ? nil : buildMenu()
        updateIcon()
    }

    private func updateIcon() {
        guard let button = statusItem.button else { return }
        let hasJSON = ClipboardMonitor.currentStringValue()
            .flatMap { JSONFormatter.format($0) } != nil
        button.image = NSImage(systemSymbolName: hasJSON ? "doc.badge.arrow.up" : "doc", accessibilityDescription: nil)
    }

    private func buildMenu() -> NSMenu {
        StatusMenuBuilder.build(
            snoozeState: snoozeState,
            onApply: { [weak self] in self?.applyTransform() },
            onSnooze: { [weak self] option in self?.applySnoze(option) },
            onQuit: { NSApp.terminate(nil) }
        )
    }

    private func applyTransform() {
        guard let input = ClipboardMonitor.currentStringValue(),
              let output = JSONFormatter.format(input) else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(output, forType: .string)
        updateIcon()
    }

    private func applySnoze(_ option: SnoozeOption) {
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
    func menuNeedsUpdate(_ menu: NSMenu) {
        statusItem.menu = buildMenu()
    }
    
    func menuDidClose(_ menu: NSMenu) {
        statusItem.menu = nil
    }
}
