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
    var wind: [Float]
    
    init(metalMesh: MetalMesh, positions: [Position], device: MTLDevice) {
        self.positions = positions
        self.count = positions.count
        let constantsBuff = device.makeBuffer(length: count * MemoryLayout<ObjectConstants>.stride, options: .storageModeShared)!
        flexibility = .init(repeating: 0, count: count)
        wind = .init(repeating: 0, count: count)
        super.init(metalMesh: metalMesh, objectConstantsBuff: constantsBuff)
    }
    
    override func updateConstantsBuffer() {
        let modelMat = position.transform
        let isTextured = metalMesh.texture != nil
        for i in 0..<count {
            let objectConstants = objectConstantsBuff.contents().advanced(by: i * MemoryLayout<ObjectConstants>.stride)
                                    .bindMemory(to: ObjectConstants.self, capacity: 1)
            
            let shearMat = float4x4.shear([flexibility[i] * wind[i], 0, 0])
            
            objectConstants.pointee.modelMatrix = modelMat * shearMat * positions[i].transform
            objectConstants.pointee.textured = isTextured ? .one : .zero
        }
    }
    
    func updateShear() {
        cnt += 0.02
        var i=0; while i<count { defer { i += 1 }
            let progress = Float(i)/Float(count)
            let t = 1.0*(cnt + progress)
            let localAmp = 0.3 * (sin(t) + sin(2*t) + sin(4*t)) + 0.25
            wind[i] = localAmp
        }
    }
}
