import simd

struct ObjectConstants {
    var modelMatrix: float4x4 = matrix_identity_float4x4
    var textured: SIMD2<Int> = .zero // treat as a boolean, boolean and int types have size issues with metal
}

struct FrameConstants {
    var viewMatrix: float4x4 = matrix_identity_float4x4
    var projectionMatrix: float4x4 = matrix_identity_float4x4
    var viewProjectionMatrix: float4x4 = matrix_identity_float4x4
    var directionalLightDir: Float3 = .zero
    var lightProjectionMatrix: float4x4 = matrix_identity_float4x4
    var spotLight: SpotLightConstants
}

struct SpotLightConstants {
    var position: Float3
    var direction: Float3
    var color: Float3
}
