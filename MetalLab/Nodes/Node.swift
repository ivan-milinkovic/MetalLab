import Foundation
import Metal
import MetalKit
import ModelIO

struct NodeMesh {
    let mesh: MDLMesh
    let submeshes: [MDLSubmesh]
    let objectConstantsBuff: MTLBuffer
    let mtkMeshBuffer: MTKMeshBuffer
}

class Node {
    var name: String = ""
    var matrix: float4x4 = .identity
    var parent: Node?
    var children: [Node] = []
    
    var nodeMesh: NodeMesh?
    
    var skeleton: MDLSkeleton?
    var animations: [MDLAnimationBindComponent] = []
    
    var transformInScene: float4x4 = .identity {
        didSet {
            if let oc = nodeMesh?.objectConstantsBuff { // meshes need a model matrix set
                let ptr = oc.contents().assumingMemoryBound(to: ObjectConstants.self)
                ptr.pointee.modelMatrix = transformInScene
            }
        }
    }
    
    func setMesh(mesh: MDLMesh, device: MTLDevice) {
        let submeshes = mesh.submeshes as! [MDLSubmesh] // has to have at least one
        var objConstantsPrototype = ObjectConstants()
        let objectConstantsBuff = device.makeBuffer(bytes: &objConstantsPrototype, length: MemoryLayout<ObjectConstants>.stride, options: .storageModeShared)!
        let mtkMeshBuffer = mesh.vertexBuffers.first as! MTKMeshBuffer // VertexData.makeModelioVertexDescriptor() defines a single buffer
        
        // Fix colors, as loaded colors are all zeros (transparent)
        let ptr = mtkMeshBuffer.buffer.contents().advanced(by: mtkMeshBuffer.offset).assumingMemoryBound(to: VertexData.self)
        for i in 0..<mesh.vertexCount {
            ptr[i].color = [1, 0, 0, 1]
        }
        
        self.nodeMesh = NodeMesh(mesh: mesh, submeshes: submeshes, objectConstantsBuff: objectConstantsBuff, mtkMeshBuffer: mtkMeshBuffer)
    }
    
    /// Depth first search
    func enumerateDFS(action: (Node) -> Void) {
        action(self)
        self.children.forEach { $0.enumerateDFS(action: action) }
    }
    
    /// Breadth first search
    func enumerateBFS(action: (Node) -> Void) {
        var queue = [self]
        while true {
            if queue.count <= 0 {
                break
            }
            let node = queue.removeFirst()
            action(node)
            queue.insert(contentsOf: node.children, at: 0)
        }
    }
    
    func printTree(depth: Int = 0) {
        let indentation = String(repeating: "  ", count: depth)
        let animCnt = animations.count
        let anims = animCnt > 0 ? "anims: \(animCnt)" : ""
        let skel = (skeleton != nil) ? "skel: \(skeleton!.name)" : ""
        print("\(indentation)\(name) \(anims) \(skel)")
        children.forEach { $0.printTree(depth: depth + 1) }
    }
}
