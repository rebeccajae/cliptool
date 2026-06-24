import Foundation

class ConfigWatcher {
    private let path: String
    private var source: DispatchSourceFileSystemObject?
    private let onChange: ([RuleConfig]) -> Void

    init(path: String = ("~/.config/clipfmt/rules.toml" as NSString).expandingTildeInPath,
         onChange: @escaping ([RuleConfig]) -> Void) {
        self.path = path
        self.onChange = onChange
    }

    func start() {
        load()
        let fd = open(path, O_EVTONLY)
        guard fd >= 0 else { return }
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: .write,
            queue: .main
        )
        source.setEventHandler { [weak self] in self?.load() }
        source.setCancelHandler { close(fd) }
        source.resume()
        self.source = source
    }

    func stop() {
        source?.cancel()
        source = nil
    }

    private func load() {
        do {
            let rules = try RuleConfig.load(from: path)
            onChange(rules)
        } catch {
            print("clipfmt: failed to load config: \(error)")
        }
    }
}
