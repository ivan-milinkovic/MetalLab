import Foundation
import Metal
import MetalKit
import ModelIO

class FileScene {
    
    var sceneNode: Node!
    var meshNodes: [Node] = []
    var transform: Transform = .init()
    
    @MainActor
    func loadTestScene(_ device: MTLDevice) {
        let url = Bundle.main.url(forResource: "coord", withExtension: "usda")!
        loadScene(url, device)
    }
    
    @MainActor
    func loadScene(_ url: URL, _ device: MTLDevice) {
        let allocator = MTKMeshBufferAllocator(device: device)
        let asset = MDLAsset(url: url, vertexDescriptor: VertexData.makeModelioVertexDescriptor(), bufferAllocator: allocator)
        sceneNode = Node()
        sceneNode.name = "Scene node - \(url.lastPathComponent)"
        
        for i in 0..<asset.count {
            let obj = asset.object(at: i)
            let node = loadMdlObject(obj, device)
            sceneNode.children.append(node)
            node.parent = sceneNode
        }
        
        sceneNode.enumerateDFS {
            if $0.nodeMesh != nil {
                meshNodes.append($0)
            }
        }
        sceneNode.printTree()
        print()
    }
    
    fileprivate func loadMdlObject(_ obj: MDLObject, _ device: MTLDevice) -> Node {
        
        let node = Node()
        node.name = obj.name
        
        if let animTransform = obj.transform {
            node.matrix = animTransform.matrix
        }
        
        if let mesh = obj as? MDLMesh {
            node.setMesh(mesh: mesh, device: device)
        }
        
        node.skeleton = obj as? MDLSkeleton
        node.animations = (obj.components.filter { $0 is MDLAnimationBindComponent } as? [MDLAnimationBindComponent]) ?? []
        
        node.children = obj.children.objects.map { cobj in
            let cnode = loadMdlObject(cobj, device)
            cnode.parent = node
            return cnode
        }
        
        return node
    }
    
    func update() {
        sceneNode.matrix = transform.matrix
        updateMatrices()
    }
    
    /// BFS is efficient by avoiding repeated calculations compared to a recursive approach. It updates nodes from parents to children, top to bottom, layer by layer, and applies only the parent matrix
    func updateMatrices() {
        sceneNode.enumerateBFS { node in
            if let parent = node.parent {
                node.transformInScene = parent.transformInScene * node.matrix
            }
            else {
                node.transformInScene = node.matrix
            }
        }
    }
}
