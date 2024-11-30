import Foundation
import simd

class Camera {
    var position: Position = .init()
    
    var projectionMatrix: float4x4 = matrix_identity_float4x4
    var viewMatrix: float4x4 { position.transform.inverse }
    
    func updateProjection(size: CGSize) {
        let vFovRads: TFloat = 60 * TFloat.pi / 180.0
        let near: TFloat = 1.0
        let far: TFloat = 100.0
        let aspect = Float(size.width) / Float(size.height)
        projectionMatrix = float4x4.perspectiveProjection(vFovRads: vFovRads, aspectRatio: aspect, near: near, far: far)
        
        //let size: Float = 2
        //projectionMatrix = float4x4.orthographicProjection(left: -size, right: size, bottom: -size, top: size, near: near, far: far)
    }
}
