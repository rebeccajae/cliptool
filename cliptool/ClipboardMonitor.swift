import AppKit

class ClipboardMonitor {
    private var timer: DispatchSourceTimer?
    private var lastChangeCount: Int = NSPasteboard.general.changeCount
    private let onChange: () -> Void

    init(onChange: @escaping () -> Void) {
        self.onChange = onChange
    }

    func start() {
        let source = DispatchSource.makeTimerSource(queue: .main)
        source.schedule(deadline: .now(), repeating: .milliseconds(500))
        source.setEventHandler { [weak self] in
            self?.poll()
        }
        source.resume()
        timer = source
    }

    func stop() {
        timer?.cancel()
        timer = nil
    }

    private func poll() {
        let current = NSPasteboard.general.changeCount
        guard current != lastChangeCount else { return }
        lastChangeCount = current
        onChange()
    }

    static func currentStringValue() -> String? {
        NSPasteboard.general.string(forType: .string)
    }
}
