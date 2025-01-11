import Foundation
import AppKit.NSEvent

class Input {
    var forward: Float = 0.0 // not booleans to avoid if statements, and just multiply
    var back:    Float = 0.0
    var right:   Float = 0.0
    var left:    Float = 0.0
    var up:      Float = 0.0
    var down:    Float = 0.0
    
    private var monitorHandle: Any?
    
    func startMonitoringEvents() {
        NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp]) { [weak self] event in
            guard let char = event.characters?.first else { return event }
            
            let isQuitCommand = char == "q" && event.modifierFlags.contains(.command)
            let isCloseCommand = char == "w" && event.modifierFlags.contains(.command)
            if isQuitCommand || isCloseCommand {
                return event
            }
            
            let isActive = event.type == .keyDown || event.isARepeat
            let isHandled = self?.keyEvent(char: char, isActive: isActive) ?? false
            return isHandled ? nil : event
        }
    }
    
    func stopMonitoringEvents() {
        NSEvent.removeMonitor(monitorHandle as Any)
    }
    
    func keyEvent(char: Character, isActive: Bool) -> Bool {
        let f: Float = isActive ? 1.0 : 0.0
        switch char {
        case "w": forward = f
        case "s": back = f
        case "a": left = f
        case "d": right = f
        case "e": up = f
        case "q": down = f
        default: return false
        }
        return true
    }
}
