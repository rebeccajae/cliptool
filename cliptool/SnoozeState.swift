import Foundation

enum SnoozeOption {
    case minutes(Int)
    case off

    var label: String {
        switch self {
        case .minutes(let n): return "Pause for \(n)m"
        case .off: return "Turn off"
        }
    }

    var interval: TimeInterval? {
        switch self {
        case .minutes(let n): return TimeInterval(n * 60)
        case .off: return nil
        }
    }
}

enum SnoozeState {
    case active
    case snoozed(SnoozeOption, skipped: Int)
    case off

    mutating func recordSkip() {
        guard case .snoozed(let option, let skipped) = self else { return }
        self = .snoozed(option, skipped: skipped + 1)
    }

    var skippedCount: Int {
        guard case .snoozed(_, let skipped) = self else { return 0 }
        return skipped
    }

    var isActive: Bool {
        if case .active = self { return true }
        return false
    }
}
