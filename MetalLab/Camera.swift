import Foundation
import simd

class Camera {
    var position: SIMD3<TFloat> = [0, 0, 4]
    var orientation: simd_quatf = simd_quatf(angle: 0.0, axis: [0, 0, -1])
    
    var projectionMatrix: float4x4 = matrix_identity_float4x4
    var viewMatrix: float4x4 = matrix_identity_float4x4
    
    func updateViewMatrix() {
        let rotMat = float4x4(orientation.inverse)
        let transMat = float4x4.init([1,0,0,0], [0,1,0,0], [0,0,1,0], SIMD4(-position, 1))
        viewMatrix = transMat * rotMat
    }
    
    func lookAt(_ p2: SIMD3<TFloat>) {
        let dir = normalize(p2 - position)
        orientation = simd_quatf(angle: 0.0, axis: dir)
    }
    
    func rotate(dx: TFloat, dy: TFloat) {
        let xq = simd_quatf(angle: dx, axis: [1, 0, 0])
        let yq = simd_quatf(angle: dy, axis: [0, 1, 0])
        orientation *= xq * yq
        
        updateViewMatrix()
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
