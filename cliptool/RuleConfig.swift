import Foundation
import CJanet

struct RegisteredRule {
    let name: String
    let trigger: TriggerMode
    let matcher: Janet
    let transform: Janet
}

enum TriggerMode {
    case always
    case manual
}
