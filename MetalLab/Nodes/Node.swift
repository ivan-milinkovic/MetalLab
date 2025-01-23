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
    
    func setMesh(mesh: MDLMesh, device: MTLDevice) {
        let submeshes = mesh.submeshes as! [MDLSubmesh] // has to have at least one
        var objConstantsPrototype = ObjectConstants()
        let objectConstantsBuff = device.makeBuffer(bytes: &objConstantsPrototype, length: MemoryLayout<ObjectConstants>.stride, options: .storageModeShared)!
        let mtkMeshBuffer = mesh.vertexBuffers.first as! MTKMeshBuffer // VertexData.makeModelioVertexDescriptor() defines a single buffer
        
        // Apply material albedo
        let ptr = mtkMeshBuffer.buffer.contents().advanced(by: mtkMeshBuffer.offset).assumingMemoryBound(to: VertexData.self)
        for sm in submeshes {
            let matProp = sm.material?.property(with: .baseColor)
            let baseColor: Float4 = matProp?.float3Value.float4_w1 ?? [0.5, 0.5, 0.5, 1]
            let ip = sm.mtkIndexBuffer.buffer.contents().assumingMemoryBound(to: UInt32.self) //bindMemory(to: UInt16.self, capacity: sm.indexCount)
            for i in 0..<sm.indexCount {
                let vertexIndex = ip[i]
                ptr[Int(vertexIndex)].color = baseColor
            }
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
//            queue.insert(contentsOf: node.children, at: 0)
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
