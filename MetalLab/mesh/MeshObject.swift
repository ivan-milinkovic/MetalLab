import Metal
import simd


class MeshObject {
    
    var transform: Transform = .init()
    let metalMesh: MetalMesh
    var objectConstantsBuff: MTLBuffer
    var tessellationFactorsBuff: MTLBuffer?
    var shouldTesselate: Bool { tessellationFactorsBuff != nil }
    var hasTransparency = false
    var material: Material
    
    init(metalMesh: MetalMesh, material: Material, device: MTLDevice) {
        self.metalMesh = metalMesh
        var prototype = ObjectConstants() // in order to have default values set in the buffer
        objectConstantsBuff = device.makeBuffer(bytes: &prototype, length: MemoryLayout<ObjectConstants>.stride, options: .storageModeShared)!
        self.material = material
    }
    
    fileprivate init(metalMesh: MetalMesh, objectConstantsBuff: MTLBuffer, material: Material) {
        self.metalMesh = metalMesh
        self.objectConstantsBuff = objectConstantsBuff
        self.material = material
        self.material.textureAmount = (material.colorTexture != nil) ? 1 : 0
    }
    
    func updateConstantsBuffer() {
        let objectConstants = getObjectConstantsPointer()
        objectConstants.pointee.modelMatrix = transform.matrix
    }
    
    @inline(__always)
    func getObjectConstantsPointer() -> UnsafeMutablePointer<ObjectConstants> {
        objectConstantsBuff.contents().bindMemory(to: ObjectConstants.self, capacity: 1)
    }
    
    func instanceCount() -> Int {
        1
    }
    
    func setupTesselationBuffer(tessellationFactor: Float, device: MTLDevice) {
        let f = unsafeBitCast(Float16(tessellationFactor), to: UInt16.self) // metal wants the bit pattern of float
        var tessellationFactors = MTLTriangleTessellationFactorsHalf(edgeTessellationFactor: (f, f, f), insideTessellationFactor: f)
        tessellationFactorsBuff = device.makeBuffer(bytes: &tessellationFactors, length: MemoryLayout<MTLQuadTessellationFactorsHalf>.stride,
                                                    options: .storageModeShared)
    }
}


class InstancedObject: MeshObject {
    
    var positions: [Transform]
    let count: Int
    
    init(metalMesh: MetalMesh, positions: [Transform], material: Material, device: MTLDevice) {
        self.positions = positions
        self.count = positions.count
        var prototypes = [ObjectConstants].init(repeating: ObjectConstants(), count: count) // in order to have default values set in the buffer
        let constantsBuff = device.makeBuffer(bytes: &prototypes, length: count * MemoryLayout<ObjectConstants>.stride, options: .storageModeShared)!
        super.init(metalMesh: metalMesh, objectConstantsBuff: constantsBuff, material: material)
    }
    
    override func updateConstantsBuffer() {
        let modelMat = transform.matrix
        let objectConstantsPtr = objectConstantsBuff.contents().assumingMemoryBound(to: ObjectConstants.self)
        var i = 0; while(i < count) { defer { i += 1}
            let objectConstants = objectConstantsPtr.advanced(by: i)
            objectConstants.pointee.modelMatrix = modelMat * positions[i].matrix
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
    
    /// The metalMesh must be fully initialized (e.g. textures)
    init(metalMesh: MetalMesh, positions: [Transform], flexibility: [Float], material: Material, device: MTLDevice) {
        self.count = positions.count
        var prototypes = [ObjectConstants].init(repeating: ObjectConstants(), count: count) // in order to have default values set in the buffer
        let constantsBuff = device.makeBuffer(bytes: &prototypes, length: count * MemoryLayout<ObjectConstants>.stride, options: .storageModeShared)!
        instanceConstantsBuff = device.makeBuffer(length: MemoryLayout<UpdateShearConstants>.stride)!
        instanceDataBuff      = device.makeBuffer(length: count * MemoryLayout<UpdateShearStrandData>.stride)!
        
        super.init(metalMesh: metalMesh, objectConstantsBuff: constantsBuff, material: material)
        
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
        let instanceDataPtr = instanceDataBuff.contents().assumingMemoryBound(to: UpdateShearStrandData.self)
        let objectConstantsPtr = objectConstantsBuff.contents().assumingMemoryBound(to: ObjectConstants.self)
        var i = 0; while(i < count) { defer { i += 1 }
            let objectConstants = objectConstantsPtr.advanced(by: i)
            objectConstants.pointee.modelMatrix = instanceDataPtr.advanced(by: i).pointee.matrix
        }
    }
    
    override func instanceCount() -> Int {
        count
    }
}
