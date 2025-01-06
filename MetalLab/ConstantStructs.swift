import simd

struct ObjectConstants {
    var modelMatrix: float4x4 = matrix_identity_float4x4
    var textureAmount: Float = 0 // how much of texture color to take and blend with vertex color
    var normalMapTiling: Float = 1
    var envMapReflectedAmount: Float = 0
    var envMapRefractedAmount: Float = 0
    var specularExponent: Float = 150
}

struct FrameConstants {
    var viewMatrix: float4x4 = matrix_identity_float4x4
    var projectionMatrix: float4x4 = matrix_identity_float4x4
    var viewProjectionMatrix: float4x4 = matrix_identity_float4x4 // used for the environment map
    var directionalLightDir: Float3 = .zero
    var lightProjectionMatrix: float4x4 = matrix_identity_float4x4
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
