import Foundation
import simd

class Joint {
    let path: String
    let name: String.SubSequence
    var children: [Joint]
    var parent: Joint?
    let matrix: float4x4
    
    init(path: String, matrix: float4x4 = .identity, children: [Joint] = [], parent: Joint? = nil) {
        self.path = path
        self.matrix = matrix
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
        print("\(indentation)\(name)")
        children.forEach { $0.printTree(depth: depth + 1) }
    }
}
