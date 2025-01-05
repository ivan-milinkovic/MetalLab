import Metal
import simd


class MeshObject {
    
    var transform: Transform = .init()
    let metalMesh: MetalMesh
    var objectConstantsBuff: MTLBuffer
    
    init(metalMesh: MetalMesh, device: MTLDevice) {
        self.metalMesh = metalMesh
        objectConstantsBuff = device.makeBuffer(length: MemoryLayout<ObjectConstants>.stride, options: .storageModeShared)!
    }
    
    fileprivate init(metalMesh: MetalMesh, objectConstantsBuff: MTLBuffer) {
        self.metalMesh = metalMesh
        self.objectConstantsBuff = objectConstantsBuff
    }
    
    func updateConstantsBuffer() {
        let objectConstants = objectConstantsBuff.contents().bindMemory(to: ObjectConstants.self, capacity: 1)
        objectConstants.pointee.modelMatrix = transform.matrix
        objectConstants.pointee.textureAmount = (metalMesh.texture != nil) ? 1 : 0
    }
    
    func instanceCount() -> Int {
        1
    }
    
    func setEnvMapReflectedAmount(_ f: Float) {
        getObjectConstantsPointer().pointee.envMapReflectedAmount = f
    }
    
    func setEnvMapRefractedAmount(_ f: Float) {
        getObjectConstantsPointer().pointee.envMapRefractedAmount = f
    }
    
    func setNormalMapTiling(_ f: Float) {
        getObjectConstantsPointer().pointee.normalMapTiling = f;
    }
    
    @inline(__always)
    func getObjectConstantsPointer() -> UnsafeMutablePointer<ObjectConstants> {
        objectConstantsBuff.contents().bindMemory(to: ObjectConstants.self, capacity: 1)
    }
}


class InstancedObject: MeshObject {
    
    var positions: [Transform]
    let count: Int
    
    init(metalMesh: MetalMesh, positions: [Transform], device: MTLDevice) {
        self.positions = positions
        self.count = positions.count
        let constantsBuff = device.makeBuffer(length: count * MemoryLayout<ObjectConstants>.stride, options: .storageModeShared)!
        super.init(metalMesh: metalMesh, objectConstantsBuff: constantsBuff)
    }
    
    override func updateConstantsBuffer() {
        let modelMat = transform.matrix
        let isTextured = metalMesh.texture != nil
        for i in 0..<count {
            let objectConstants = objectConstantsBuff.contents().advanced(by: i * MemoryLayout<ObjectConstants>.stride)
                                    .bindMemory(to: ObjectConstants.self, capacity: 1)
            objectConstants.pointee.modelMatrix = modelMat * positions[i].matrix
            objectConstants.pointee.textureAmount = isTextured ? 1.0 : 0.0
        }
    }
    
    override func instanceCount() -> Int {
        count
    }
}


class AnimatedInstancedObject: MeshObject {
    
    let count: Int
    let instanceConstantsBuff: MTLBuffer
    let instanceDataBuff: MTLBuffer
    
    init(metalMesh: MetalMesh, positions: [Transform], flexibility: [Float], device: MTLDevice) {
        self.count = positions.count
        let constantsBuff = device.makeBuffer(length: count * MemoryLayout<ObjectConstants>.stride, options: .storageModeShared)!
        instanceConstantsBuff = device.makeBuffer(length: MemoryLayout<UpdateShearConstants>.stride)!
        instanceDataBuff      = device.makeBuffer(length: count * MemoryLayout<UpdateShearStrandData>.stride)!
        
        super.init(metalMesh: metalMesh, objectConstantsBuff: constantsBuff)
        
        updateInstanceDataBuff(positions: positions, flexibility: flexibility)
    }
    
    func updateInstanceDataBuff(positions: [Transform], flexibility: [Float]) {
        let instanceDataPtr = instanceDataBuff.contents().assumingMemoryBound(to: UpdateShearStrandData.self)
        for i in 0..<count {
            var data = instanceDataPtr.advanced(by: i).pointee
            data.position = positions[i].position
            data.orientQuat = positions[i].orientation.vector
            data.scale = positions[i].scale
            data.shear = positions[i].shear
            data.matrix = matrix_identity_float4x4
            data.flexibility = flexibility[i]
            instanceDataPtr.advanced(by: i).pointee = data
        }
    }
    
    override func updateConstantsBuffer() {
        let isTextured = metalMesh.texture != nil
        let instanceDataPtr = instanceDataBuff.contents().assumingMemoryBound(to: UpdateShearStrandData.self)
        for i in 0..<count {
            let objectConstants = objectConstantsBuff.contents().advanced(by: i * MemoryLayout<ObjectConstants>.stride)
                                    .bindMemory(to: ObjectConstants.self, capacity: 1)
            objectConstants.pointee.modelMatrix = instanceDataPtr.advanced(by: i).pointee.matrix
            objectConstants.pointee.textureAmount = isTextured ? 1.0 : 0.0
        }
    }
    
    override func instanceCount() -> Int {
        count
    }
}
