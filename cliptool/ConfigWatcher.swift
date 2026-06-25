import Foundation
import JanetKit

class ConfigWatcher {
    private let path: String
    private var source: DispatchSourceFileSystemObject?
    private let onChange: ([RegisteredRule]) -> Void
    private let janet: JanetVM

    init(path: String = ("~/.config/clipfmt/config.janet" as NSString).expandingTildeInPath,
         janet: JanetVM,
         onChange: @escaping ([RegisteredRule]) -> Void) {
        self.path = path
        self.janet = janet
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
            let source = try String(contentsOfFile: path, encoding: .utf8)
            RuleStorage.rules = []
            _ = try janet.eval(source: source)
            onChange(RuleStorage.rules)
        } catch {
            print("clipfmt: failed to load config: \(error)")
        }
    }
}
