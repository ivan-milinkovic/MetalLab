import Foundation
import QuartzCore

final class Time: Sendable {
    static let shared = Time()
    let start: TimeInterval = CACurrentMediaTime()
    var current: TimeInterval { CACurrentMediaTime() - start }
}
