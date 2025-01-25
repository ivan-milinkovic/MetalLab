import Foundation
import Metal
import MetalKit
import ModelIO

class FileScene {
    
    var sceneNode: Node!
    var meshNodes: [Node] = []
    var transform: Transform = .init()
    var skeletonNode: Node?
    var skeleton: Skeleton?
    
    var animate = false {
        didSet {
            if let anim = skeletonNode?.nodeAnimations.first {
                if animate {
                    anim.ensureMarkStart()
                }
                else {
                    anim.markStop()
                    skeleton?.setRestPose()
                }
            }
        }
    }
    
    @MainActor
    func loadTestScene(_ device: MTLDevice) {
        //let url = Bundle.main.url(forResource: "coord2", withExtension: "usda")!
        let url = Bundle.main.url(forResource: "Character", withExtension: "usda")!
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
        
        // Collect mesh nodes for easier access in the renderer
        sceneNode.enumerateDFS {
            if $0.nodeMesh != nil {
                meshNodes.append($0)
            }
        }
        
        // Find one skeleton
        sceneNode.enumerateBFS { node, stop in
            if let skel = node.nodeSkeleton {
                self.skeletonNode = node
                self.skeleton = skel
                self.skeleton?.nodeMatrix = node.matrix
                stop = true
            }
        }
        
        //sceneNode.printTree()
        
        skeletonNode?.nodeAnimations.first?.markStart()
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
        
        if let skeleton = obj as? MDLSkeleton {
            node.nodeSkeleton = Skeleton(skeleton: skeleton)
        }
        
        if let animComponents = (obj.components.filter { $0 is MDLAnimationBindComponent } as? [MDLAnimationBindComponent]) {
            node.nodeAnimations = animComponents.compactMap { NodeAnimation(mdlAnimComponent: $0) }
        }
        
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
        sceneNode.enumerateBFS { node, _ in
            if let parent = node.parent {
                node.transformInScene = parent.transformInScene * node.matrix
            }
            else {
                node.transformInScene = node.matrix
            }
        }
        
        if animate, let anim = skeletonNode?.nodeAnimations.first {
            skeleton?.animate(animation: anim)
        }
    }
    
    func moveAsCharacter(dfwd: Float, dside: Float) {
        let ds = Float3(dside, 0, dfwd)
        if length_squared(ds) < 0.0001 {
            return
        }
        let fwd = normalize(ds)
        let up = Float3(0, 1, 0)
        let right = normalize(cross(up, fwd))
        transform.orientation = simd_quatf(float3x3(right, up, fwd))
        transform.moveBy(ds)
    }
    
}
