import Metal
import simd

class MeshObject {
    
    var positionOrientation: PositionOrientation = .init()
    let metalMesh: MetalMesh
    var objectStaticDataBuff: MTLBuffer
    
    init(metalMesh: MetalMesh, device: MTLDevice) {
        self.metalMesh = metalMesh
        objectStaticDataBuff = device.makeBuffer(length: MemoryLayout<ObjectStaticData>.size, options: .storageModeShared)!
    }
}

struct ObjectStaticData {
    var modelViewProjectionMatrix: float4x4 = matrix_identity_float4x4
    var modelViewInverseTransposeMatrix: float4x4 = matrix_identity_float4x4
    var textured: SIMD2<Int> = [0,0] // treat as a boolean, boolean and int types have size issues with metal
    var directionalLightDir: Float4 = .zeros
}