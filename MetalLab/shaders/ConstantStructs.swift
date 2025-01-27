import simd

struct ObjectConstants {
    var modelMatrix: float4x4 = .identity
}

struct MaterialConstants {
    let color: Float3
    let metalness: Float
    let roughness: Float
    let ambientOcclusion: Float
    let opacity: Float
    
    let textureAmount: Float
    let textureTiling: Float
    let normalMapTiling: Float
    let envMapReflectedAmount: Float
    let envMapRefractedAmount: Float
    let specularExponent: Float
    let displacementFactor: Float
}

struct FrameConstants {
    var viewMatrix: float4x4 = .identity
    var projectionMatrix: float4x4 = .identity
    var viewProjectionMatrix: float4x4 = .identity // used for the environment map
    var directionalLightDir: Float3 = .zero
    var lightProjectionMatrix: float4x4 = .identity
    var spotLight: SpotLightConstants
}

struct SpotLightConstants {
    var position: Float3
    var direction: Float3
    var color: Float3
}

struct UpdateShearConstants {
    var timeCounter: Float
    var count: UInt32
    var windStrength: Float
    var windDir: Float3
    var containerMat: float4x4
}

struct UpdateShearStrandData {
    var matrix: float4x4
    var position: Float3
    var scale: Float
    var orientQuat: Float4
    var shear: Float3
    var flexibility: Float
}
