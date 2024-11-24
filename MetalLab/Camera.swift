import Foundation
import simd

class Camera {
    var positionOrientation: PositionOrientation = .init()
    
    var projectionMatrix: float4x4 = matrix_identity_float4x4
    var viewMatrix: float4x4 { positionOrientation.transform }
    
    func lookAt(_ p2: SIMD3<TFloat>) {
        let dir = normalize(p2 - positionOrientation.position)
        positionOrientation.orientation = simd_quatf(angle: 0.0, axis: dir)
    }
    
    func rotate(dx: TFloat, dy: TFloat) {
        positionOrientation.rotate(dx: dx, dy: dy)
    }
    
    func updateProjection(size: CGSize) {
        let fovRads: TFloat = 60 * TFloat.pi / 180.0
        let near: TFloat = 1.0
        let far: TFloat = 100.0
        let aspect = Float(size.width) / Float(size.height)
        
        // right-handed
        let Sy = 1 / tan(fovRads * 0.5)
        let Sx = Sy / aspect
        let dz = far - near
        let Sz = -(far + near) / dz
        let Tz = -2 * (far * near) / dz
        
        projectionMatrix = float4x4(
            SIMD4(Sx, 0,  0,  0),
            SIMD4(0, Sy,  0,  0),
            SIMD4(0,  0, Sz, -1),
            SIMD4(0,  0,  Tz, 0)
        )
    }
}
