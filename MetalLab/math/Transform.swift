import simd

struct Transform {
    var position: Float3 = [0, 0, 0] {
        didSet { updateTransform() }
    }
    
    var orientation: simd_quatf = simd_quatf(angle: 0.0, axis: [0, 0, 1]) {
        didSet { updateTransform() }
    }
    
    var scale: Float = 1.0 {
        didSet { updateTransform() }
    }
    
    var shear: Float3 = .zero {
        didSet { updateTransform() }
    }
    
    var matrix: float4x4 = matrix_identity_float4x4
    
    init() {
        updateTransform()
    }
    
    init(position: Float3 = .zero, orientation: simd_quatf = simd_quatf(angle: 0.0, axis: [0, 0, 1]), scale: Float = 1.0, shear: Float3 = .zero) {
        self.position = position
        self.orientation = orientation
        self.scale = scale
        self.shear = shear
        updateTransform()
    }
    
    mutating func moveBy(_ dv: Float3) {
        position += dv
    }
    
    mutating func move(d_forward: Float, d_right: Float, d_up: Float) {
        let mat = float4x4(orientation)
        let rot = mat.upperLeftMat3x3()
        let right =  rot.columns.0 // x
        let up    =  rot.columns.1 // y
        let fwd   = -rot.columns.2 // z, in right handed sytem forward is -z
        position += fwd * d_forward + right * d_right + up * d_up
    }
    
    // todo: needs fixing
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
    
    mutating func lookAt(_ p: Float3) {
        look(from: position, at: p)
    }
    
    mutating func rotate(dx: Float = 0.0, dy: Float = 0.0, dz: Float = 0.0) {
        let xq = simd_quatf(angle: dx, axis: [1, 0, 0])
        let yq = simd_quatf(angle: dy, axis: [0, 1, 0])
        let zq = simd_quatf(angle: dz, axis: [0, 0, 1])
        orientation = orientation * xq * yq * zq
    }
    
    // avoid roll https://gamedev.stackexchange.com/a/136175
    mutating func rotate2(dx: Float = 0.0, dy: Float = 0.0) {
        let xq = simd_quatf(angle: dx, axis: [1, 0, 0])
        let yq = simd_quatf(angle: dy, axis: [0, 1, 0])
        orientation = yq * orientation * xq
    }
    
    mutating func updateTransform() {
        var scaleMat = matrix_identity_float4x4 * scale;
        scaleMat.columns.3.w = 1
        let rotMat = float4x4(orientation)
        let transMat = float4x4.init([1,0,0,0], [0,1,0,0], [0,0,1,0], SIMD4(position, 1))
        let shearMat = float4x4.shear(shear)
        matrix = transMat * rotMat * scaleMat * shearMat
    }
}
