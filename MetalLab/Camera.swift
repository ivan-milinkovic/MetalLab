import Foundation
import simd

class Camera {
    var position: SIMD3<TFloat> = [0, 0, 0]
    var orientation: simd_quatf = simd_quatf(angle: 0.0, axis: [0, 0, -1])
    
    func lookAt(_ p2: SIMD3<TFloat>) {
        let dir = normalize(p2 - position)
        orientation = simd_quatf(angle: 0.0, axis: dir)
    }
}
