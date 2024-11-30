import Metal
import simd

class MeshObject {
    var position: Position = .init()
    let metalMesh: MetalMesh
    var objectStaticDataBuff: MTLBuffer
    
    init(metalMesh: MetalMesh, device: MTLDevice) {
        self.metalMesh = metalMesh
        objectStaticDataBuff = device.makeBuffer(length: MemoryLayout<ObjectStaticData>.size, options: .storageModeShared)!
    }
}

struct ObjectStaticData {
    var modelViewMatrix: float4x4 = matrix_identity_float4x4
    var modelViewProjectionMatrix: float4x4 = matrix_identity_float4x4
    var modelViewInverseTransposeMatrix: float4x4 = matrix_identity_float4x4
    var modelLightProjectionMatrix: float4x4 = matrix_identity_float4x4
    
    var textured: SIMD2<Int> = .zero // treat as a boolean, boolean and int types have size issues with metal
    
    var directionalLightDir: Float4 = .zeros
    var spotLight: SpotLightStaticData
}

struct SpotLightStaticData {
    var position: Float3
    var direction: Float3
    var color: Float3
}
