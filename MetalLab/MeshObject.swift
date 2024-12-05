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


class InstancedObject: MeshObject {
    
    let positions: [Position]
    let count: Int
    
    var cnt: Float = 0.0
    var flexibility: [Float] // additional shear factor per instance
    var shear: [Float3]
    
    init(metalMesh: MetalMesh, positions: [Position], device: MTLDevice) {
        self.positions = positions
        self.count = positions.count
        let constantsBuff = device.makeBuffer(length: count * MemoryLayout<ObjectConstants>.stride, options: .storageModeShared)!
        flexibility = .init(repeating: 0, count: count)
        shear = .init(repeating: .zero, count: count)
        super.init(metalMesh: metalMesh, objectConstantsBuff: constantsBuff)
    }
    
    override func updateConstantsBuffer() {
        let modelMat = position.transform
        let isTextured = metalMesh.texture != nil
        for i in 0..<count {
            let objectConstants = objectConstantsBuff.contents().advanced(by: i * MemoryLayout<ObjectConstants>.stride)
                                    .bindMemory(to: ObjectConstants.self, capacity: 1)
            
            let shearMat = float4x4.shear( shear[i] * flexibility[i] )
            objectConstants.pointee.modelMatrix = modelMat * positions[i].transform * shearMat
            objectConstants.pointee.textured = isTextured ? .one : .zero
        }
    }
    
    func updateShear(timeCounter: Double, wind: Wind) {
        let modelMat = position.transform
        var i=0; while i<count { defer { i += 1 }
            let pos = (modelMat * positions[i].position.float4_w1).xyz
            let sample = wind.sample(position: pos, timeCounter: timeCounter)
            self.shear[i] = sample
        }
    }
}
