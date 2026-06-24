import AppKit

enum StatusMenuBuilder {
    static func build(
        always: [RuleConfig],
        manual: [RuleConfig],
        snoozeState: SnoozeState,
        onApply: @escaping (RuleConfig) -> Void,
        onSnooze: @escaping (SnoozeOption) -> Void,
        onQuit: @escaping () -> Void
    ) -> NSMenu {
        let menu = NSMenu()

        if case .off = snoozeState {
            menu.addItem(header("clipfmt is off"))
        } else if case .snoozed(_, let skipped) = snoozeState {
            let label = skipped > 0 ? "Snoozed — \(skipped) skipped" : "Snoozed"
            menu.addItem(header(label))
        } else if always.count > 1 {
            menu.addItem(header("\(always.count) auto rules matched — pick one"))
            for rule in always {
                menu.addItem(actionItem(title: rule.name, action: { onApply(rule) }))
            }
        } else if !always.isEmpty || !manual.isEmpty {
            for rule in always + manual {
                menu.addItem(actionItem(title: rule.name, action: { onApply(rule) }))
            }
        } else {
            menu.addItem(header("Nothing to format"))
        }

        menu.addItem(.separator())

        let snoozeMenu = NSMenu()
        for option in [SnoozeOption.minutes(5), .minutes(30), .off] {
            snoozeMenu.addItem(actionItem(title: option.label, action: { onSnooze(option) }))
        }
        if snoozeState.isActive {
            let snoozeItem = NSMenuItem(title: "Snooze", action: nil, keyEquivalent: "")
            snoozeItem.submenu = snoozeMenu
            menu.addItem(snoozeItem)
        } else {
            menu.addItem(actionItem(title: "Resume", action: { onSnooze(.minutes(0)) }))
        }

        menu.addItem(.separator())
        menu.addItem(actionItem(title: "Quit", action: onQuit))

        return menu
    }

    private static func header(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    private static func actionItem(title: String, action: @escaping () -> Void) -> NSMenuItem {
        let item = BlockMenuItem(title: title, action: action)
        return item
    }
}

class BlockMenuItem: NSMenuItem {
    private let block: () -> Void

    init(title: String, action: @escaping () -> Void) {
        self.block = action
        super.init(title: title, action: #selector(fire), keyEquivalent: "")
        self.target = self
    }

    required init(coder: NSCoder) { fatalError() }

    @objc private func fire() { block() }
}

