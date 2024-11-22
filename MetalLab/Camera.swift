import Foundation
import simd

class Camera {
    var position: SIMD3<TFloat> = [0, 0, 4]
    var orientation: simd_quatf = simd_quatf(angle: 0.0, axis: [0, 0, -1])
    
    func lookAt(_ p2: SIMD3<TFloat>) {
        let dir = normalize(p2 - position)
        orientation = simd_quatf(angle: 0.0, axis: dir)
    }
    
    func rotate(dx: TFloat, dy: TFloat) {
        let xq = simd_quatf(angle: dx, axis: [1, 0, 0])
        let yq = simd_quatf(angle: dy, axis: [0, 1, 0])
        orientation *= xq * yq
    }
}
