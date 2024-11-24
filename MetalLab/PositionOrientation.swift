import simd

struct PositionOrientation {
    var position: SIMD3<TFloat> = [0, 0, 0] {
        didSet { updateTransform() }
    }
    
    var orientation: simd_quatf = simd_quatf(angle: 0.0, axis: [0, 0, 1]) {
        didSet { updateTransform() }
    }
    
    var transform: float4x4 = matrix_identity_float4x4
    
    init() {
        updateTransform()
    }
    
    mutating func moveBy(_ dv: Float3) {
        position += dv
    }
    
    mutating func look(from: Float3, at: Float3) {
        position = from
        orientation = simd_quatf.init(angle: 0.0, axis: normalize(at - from))
    }
    
    mutating func lookAt(_ p2: SIMD3<TFloat>) {
        let dir = normalize(p2 - position)
        orientation = simd_quatf(angle: 0.0, axis: dir)
    }
    
    mutating func rotate(dx: TFloat = 0.0, dy: TFloat = 0.0, dz: TFloat = 0.0) {
        let xq = simd_quatf(angle: dx, axis: [1, 0, 0])
        let yq = simd_quatf(angle: dy, axis: [0, 1, 0])
        let zq = simd_quatf(angle: dz, axis: [0, 0, 1])
        orientation = orientation * xq * yq * zq
    }
    
    mutating func updateTransform() {
        let rotMat = float4x4(orientation)
        let transMat = float4x4.init([1,0,0,0], [0,1,0,0], [0,0,1,0], SIMD4(position, 1))
        transform = transMat * rotMat
    }
}
