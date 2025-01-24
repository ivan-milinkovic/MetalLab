import Foundation
import simd

class Joint {
    let path: String
    let index: Int
    var children: [Joint]
    var parent: Joint?
    let name: String.SubSequence
    
    init(path: String, index: Int, children: [Joint] = [], parent: Joint? = nil) {
        self.path = path
        self.index = index
        self.children = children
        self.parent = parent
        
        if let lastSlash = path.lastIndex(of: "/") {
            let i = path.index(after: lastSlash)
            name = path[i...]
        } else {
            name = path[...]
        }
    }
    
    func enumerateDFS(action: (Joint) -> Void) {
        action(self)
        self.children.forEach { $0.enumerateDFS(action: action) }
    }
    
    func enumerateBFS(action: (Joint) -> Void) {
        var queue = [self]
        while true {
            if queue.count <= 0 {
                break
            }
            let joint = queue.removeFirst()
            action(joint)
            queue.append(contentsOf: joint.children)
        }
    }
    
    func printTree(depth: Int = 0) {
        let indentation = String(repeating: "  ", count: depth)
        let parentInd = (parent?.index ?? -1).description
        print("\(indentation)\(index): \(name) (\(parentInd))")
        children.forEach { $0.printTree(depth: depth + 1) }
    }
}
