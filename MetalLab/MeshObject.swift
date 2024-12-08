import Metal
import simd


class MeshObject {
    
    var transform: Transform = .init()
    let metalMesh: MetalMesh
    var objectConstantsBuff: MTLBuffer
    
    init(metalMesh: MetalMesh, device: MTLDevice) {
        self.metalMesh = metalMesh
        objectConstantsBuff = device.makeBuffer(length: MemoryLayout<ObjectConstants>.size, options: .storageModeShared)!
    }
    
    fileprivate init(metalMesh: MetalMesh, objectConstantsBuff: MTLBuffer) {
        self.metalMesh = metalMesh
        self.objectConstantsBuff = objectConstantsBuff
    }
    
    func updateConstantsBuffer() {
        let objectConstants = objectConstantsBuff.contents().bindMemory(to: ObjectConstants.self, capacity: 1)
        objectConstants.pointee.modelMatrix = transform.matrix
        objectConstants.pointee.textured = (metalMesh.texture != nil) ? .one : .zero
    }
}


class InstancedObject: MeshObject {
    
    var positions: [Transform]
    let count: Int
    var flexibility: [Float] // additional shear factor per instance
    
    init(metalMesh: MetalMesh, positions: [Transform], device: MTLDevice) {
        self.positions = positions
        self.count = positions.count
        let constantsBuff = device.makeBuffer(length: count * MemoryLayout<ObjectConstants>.stride, options: .storageModeShared)!
        flexibility = .init(repeating: 0, count: count)
        super.init(metalMesh: metalMesh, objectConstantsBuff: constantsBuff)
    }
    
    override func updateConstantsBuffer() {
        let modelMat = transform.matrix
        let isTextured = metalMesh.texture != nil
        for i in 0..<count {
            let objectConstants = objectConstantsBuff.contents().advanced(by: i * MemoryLayout<ObjectConstants>.stride)
                                    .bindMemory(to: ObjectConstants.self, capacity: 1)
            objectConstants.pointee.modelMatrix = modelMat * positions[i].matrix
            objectConstants.pointee.textured = isTextured ? .one : .zero
        }
    }
}
