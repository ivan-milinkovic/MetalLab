import simd

let epsilon: Float = 0.00002

typealias Float2 = SIMD2<Float>
typealias Float3 = SIMD3<Float>
typealias Float4 = SIMD4<Float>

extension Float4 {
    static var randomOpaqueColor: Float4 {
        .init(Float.random(in: 0...1), Float.random(in: 0...1), Float.random(in: 0...1), 1)
    }
    
    var xyz: Float3 {
        Float3(x, y, z)
    }
}

extension Float3 {
    var float4_w1: Float4 {
        Float4(x, y, z, 1)
    }
    
    var float4_w0: Float4 {
        Float4(x, y, z, 0)
    }
}

extension float4x4 {
    init(rotationRads rads: Float, axis: Float3) {
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
    
    static func make(t: Float3, r: simd_quatf, s: Float3) -> float4x4 {
        let sm = float4x4(diagonal: Float4(s, 1))
        let rm = float4x4(r)
        let tm = float4x4([1,0,0,0], [0,1,0,0], [0,0,1,0], [t.x, t.y, t.z, 1])
        return tm * rm * sm
    }
    
    // ref: https://github.com/metal-by-example/thirty-days-of-metal/blob/master/28/MetalVertexSkinning/MetalVertexSkinning/Math.swift
    // Shouldn't scale be on the diagonal only?
    init(t: Float3, r: simd_quatf, s: Float3) {
        let rm = float3x3(r)
        self.init(Float4( s.x * rm.columns.0, 0),
                  Float4( s.y * rm.columns.1, 0),
                  Float4( s.z * rm.columns.2, 0),
                  Float4( t, 1))
    }
    
    static func perspectiveProjection(vFovRads: Float, aspectRatio: Float, near: Float, far: Float) -> float4x4 {
        // right-handed
        let Sy = 1 / tan(vFovRads * 0.5)
        let Sx = Sy / aspectRatio
        let dz = far - near
        let Sz = -(far + near) / dz
        let Tz = -2 * (far * near) / dz
        return float4x4(
            SIMD4(Sx, 0,  0,  0),
            SIMD4(0, Sy,  0,  0),
            SIMD4(0,  0, Sz, -1),
            SIMD4(0,  0,  Tz, 0)
        )
    }
    
    static func orthographicProjection(left  : Float, right: Float,
                                       bottom: Float, top  : Float,
                                       near  : Float, far  : Float) -> float4x4 {
        let sx = 2 / (right - left)
        let sy = 2 / (top - bottom)
        let sz = 1 / (near - far)
        let tx = (left + right) / (left - right)
        let ty = (top + bottom) / (bottom - top)
        let tz = near / (near - far)
        return float4x4(SIMD4<Float>(sx,  0,  0, 0),
                        SIMD4<Float>( 0, sy,  0, 0),
                        SIMD4<Float>( 0,  0, sz, 0),
                        SIMD4<Float>(tx, ty, tz, 1))
    }
    
    static func shear(_ shear: Float3) -> float4x4 {
        return float4x4(Float4(1, shear.y, shear.z, 0),
                        Float4(shear.x, 1, shear.z, 0),
                        Float4(0, 0, 1, 0),
                        Float4(0, 0, 0, 1))
    }
    
    func upperLeftMat3x3() -> float3x3 {
        float3x3(columns.0.xyz, columns.1.xyz, columns.2.xyz)
    }
}
