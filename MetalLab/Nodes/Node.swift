import Foundation
import Metal
import MetalKit
import ModelIO

class Node {
    var name: String = ""
    var matrix: float4x4 = .identity
    var parent: Node?
    var children: [Node] = []
    
    var nodeMesh: NodeMesh?
    var nodeSkeleton: Skeleton?
    var nodeAnimations: [NodeAnimation] = []
    
    var transformInScene: float4x4 = .identity {
        didSet {
            if let oc = nodeMesh?.objectConstantsBuff { // meshes need a model matrix set
                let ptr = oc.contents().assumingMemoryBound(to: ObjectConstants.self)
                ptr.pointee.modelMatrix = transformInScene
            }
        }
    }
    
    /// Depth first search
    func enumerateDFS(action: (Node) -> Void) {
        action(self)
        self.children.forEach { $0.enumerateDFS(action: action) }
    }
    
    /// Breadth first search
    func enumerateBFS(action: (Node, inout Bool) -> Void) {
        var stop = false
        var queue = [self]
        while true {
            if queue.count <= 0 {
                break
            }
            let node = queue.removeFirst()
            action(node, &stop)
            if stop == true {
                break
            }
            queue.append(contentsOf: node.children)
        }
    }
    
    func printTree(depth: Int = 0) {
        let indentation = String(repeating: "  ", count: depth)
        let animCnt = nodeAnimations.count
        let anims = animCnt > 0 ? "anims: \(animCnt)" : ""
        let skel = (nodeSkeleton != nil) ? "skel: \(nodeSkeleton!.skeleton.name)" : ""
        print("\(indentation)\(name) \(anims) \(skel)")
        children.forEach { $0.printTree(depth: depth + 1) }
    }
}
