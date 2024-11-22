import simd

typealias Float2 = SIMD2<Float>
typealias Float3 = SIMD3<Float>
typealias Float4 = SIMD4<Float>

extension Float4 {
    static var zeros: Float4 { .init(repeating: 0) }
    static var ones: Float4 { .init(repeating: 1) }
    static var randomOpaqueColor: Float4 {
        .init(Float.random(in: 0...1), Float.random(in: 0...1), Float.random(in: 0...1), 1)
    }
}

extension float4x4 {
    init(rotationRads rads: Float, axis: SIMD3<Float>) {
        let x = axis.x
        let y = axis.y
        let z = axis.z
        let s = sin(rads)
        let c = cos(rads)

        let M = simd_float4x4(
            SIMD4<Float>(x*x + (1-x*x) * c,  x*y*(1 - c) - z*s,  x*z*(1 - c) + y*s,  0),
            SIMD4<Float>(x*y * (1-c) + z*s,  y*y + (1 - y*y)*c,  y*z*(1-c) - x*s  ,  0),
            SIMD4<Float>(x*z * (1-c) - y*s,  y*z*(1-c) + x*s  ,  z*z + (1 - z*z)*c,  0),
            SIMD4<Float>(                0,                  0,                  0,  1)
        ).transpose
        
        self.init(columns: M.columns)
    }
}
