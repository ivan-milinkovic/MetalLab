import simd

// Samples strength based on input position vector
class Wind {
    
    var dir: Float3 = normalize(Float3(1, 0, 0.5)) {
        didSet {
            dir = normalize(dir)
        }
    }
    var strength: Float = 0.3
    
    func sample(position: Float3, timeCounter: Double) -> Float3 {
        var t = position + Float(timeCounter)
        t *= 0.75 // adjust wave length
        var x = strength * (sin(t.x) + sin(2*t.x) + sin(4*t.x)) + 0.25
        var y = strength * (sin(t.y) + sin(2*t.y) + sin(4*t.y)) + 0.25
        var z = strength * (sin(t.z) + sin(2*t.z) + sin(4*t.z)) + 0.25
        x *= dir.x
        y *= dir.y
        z *= dir.z
        return Float3(x, y, z)
    }
}
