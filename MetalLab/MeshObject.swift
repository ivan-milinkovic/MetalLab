import Metal
import simd


class MeshObject {
    
    var position: Position = .init()
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
        objectConstants.pointee.modelMatrix = position.transform
        objectConstants.pointee.textured = (metalMesh.texture != nil) ? .one : .zero
    }
}


class ClusterObject: MeshObject {
    
    let positions: [Position]
    let count: Int
    
    init(metalMesh: MetalMesh, positions: [Position], device: MTLDevice) {
        self.positions = positions
        self.count = positions.count
        let constantsBuff = device.makeBuffer(length: count * MemoryLayout<ObjectConstants>.stride, options: .storageModeShared)!
        super.init(metalMesh: metalMesh, objectConstantsBuff: constantsBuff)
    }
    
    override func updateConstantsBuffer() {
        let modelMat = position.transform
        let isTextured = metalMesh.texture != nil
        for i in 0..<count {
            let objectConstants = objectConstantsBuff.contents().advanced(by: i * MemoryLayout<ObjectConstants>.stride)
                                    .bindMemory(to: ObjectConstants.self, capacity: 1)
            objectConstants.pointee.modelMatrix = modelMat * positions[i].transform
            objectConstants.pointee.textured = isTextured ? .one : .zero
        }
    }
}
