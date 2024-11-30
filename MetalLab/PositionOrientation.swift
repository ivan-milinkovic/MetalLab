import simd

struct PositionOrientation {
    var position: SIMD3<TFloat> = [0, 0, 0] {
        didSet { updateTransform() }
    }
    
    var orientation: simd_quatf = simd_quatf(angle: 0.0, axis: [0, 0, 1]) {
        didSet { updateTransform() }
    }
    
    var scale: Float = 1.0 {
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
        let toDir = normalize(at - from)
        let ref = Float3(0, 0, -1)
        let dot = dot(ref, toDir)
        let angle = acos(dot)
        var axis = cross(ref, toDir)
        if length(axis) < 0.001 {
            axis = ref
        }
        axis = normalize(axis)
        orientation = simd_quatf(angle: angle, axis: axis)
    }
    
    mutating func lookAt(_ p: SIMD3<TFloat>) {
        look(from: position, at: p)
    }
    
    mutating func rotate(dx: TFloat = 0.0, dy: TFloat = 0.0, dz: TFloat = 0.0) {
        let xq = simd_quatf(angle: dx, axis: [1, 0, 0])
        let yq = simd_quatf(angle: dy, axis: [0, 1, 0])
        let zq = simd_quatf(angle: dz, axis: [0, 0, 1])
        orientation = orientation * xq * yq * zq
    }
    
    mutating func updateTransform() {
        var scaleMat = matrix_identity_float4x4 * scale;
        scaleMat.columns.3.w = 1
        let rotMat = float4x4(orientation)
        let transMat = float4x4.init([1,0,0,0], [0,1,0,0], [0,0,1,0], SIMD4(position, 1))
        transform = transMat * rotMat * scaleMat
    }
}
