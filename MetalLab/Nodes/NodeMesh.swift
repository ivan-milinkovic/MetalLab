import Metal
import MetalKit
import ModelIO

/// Easier access to mesh properties and conversion from MDL to MTK models
struct NodeMesh {
    let mesh: MDLMesh
    let submeshes: [SubMesh]
    let objectConstantsBuff: MTLBuffer
    let mtkMeshBuffer: MTKMeshBuffer
    
    init(mesh: MDLMesh, device: MTLDevice) {
        self.mesh = mesh
        self.mtkMeshBuffer = mesh.vertexBuffers.first as! MTKMeshBuffer // VertexData.makeModelioVertexDescriptor() defines a single buffer
        var objConstantsPrototype = ObjectConstants()
        objectConstantsBuff = device.makeBuffer(bytes: &objConstantsPrototype, length: MemoryLayout<ObjectConstants>.stride, options: .storageModeShared)!
        self.submeshes = (mesh.submeshes as! [MDLSubmesh]).map { mdlSubmesh in // has to have at least one
            let matProp = mdlSubmesh.material?.property(with: .baseColor)
            let baseColor: Float3 = matProp?.float3Value ?? [0.5, 0.5, 0.5]
            return SubMesh(mdlSubmesh: mdlSubmesh, material: Material(color: baseColor))
        }
    }
}

struct SubMesh {
    let mdlSubmesh: MDLSubmesh
    let material: Material
}
