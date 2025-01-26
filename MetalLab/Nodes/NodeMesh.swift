import Metal
import MetalKit
import ModelIO

/// Easier access to mesh properties and conversion from MDL to MTK models
struct NodeMesh {
    let mesh: MDLMesh
    let submeshes: [MDLSubmesh]
    let objectConstantsBuff: MTLBuffer
    let mtkMeshBuffer: MTKMeshBuffer
    
    init(mesh: MDLMesh, device: MTLDevice) {
        self.mesh = mesh
        self.submeshes = mesh.submeshes as! [MDLSubmesh] // has to have at least one
        self.mtkMeshBuffer = mesh.vertexBuffers.first as! MTKMeshBuffer // VertexData.makeModelioVertexDescriptor() defines a single buffer
        var objConstantsPrototype = ObjectConstants()
        objectConstantsBuff = device.makeBuffer(bytes: &objConstantsPrototype, length: MemoryLayout<ObjectConstants>.stride, options: .storageModeShared)!
        
        // Apply material albedo
        let ptr = mtkMeshBuffer.buffer.contents().advanced(by: mtkMeshBuffer.offset).assumingMemoryBound(to: VertexData.self)
        //for i in 0..<mesh.vertexCount {
        //    ptr[i].color = [1, 0, 0, 1]
        //}
        
        for sm in submeshes {
            let matProp = sm.material?.property(with: .baseColor)
            let baseColor: Float4 = matProp?.float3Value.float4_w1 ?? [0.5, 0.5, 0.5, 1]
            let ip = sm.mtkIndexBuffer.buffer.contents().assumingMemoryBound(to: UInt32.self) //bindMemory(to: UInt16.self, capacity: sm.indexCount)
            for i in 0..<sm.indexCount {
                let vertexIndex = ip[i]
                ptr[Int(vertexIndex)].color = baseColor
            }
        }
    }
}
