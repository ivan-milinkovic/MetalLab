import Metal

struct Material {
    
    var color: Float3 = [1, 1, 1]
    var opacity: Float = 1
    var colorTexture: MTLTexture?
    var textureAmount: Float = 0 // how much of texture color to take and blend with vertex color
    var textureTiling: Float = 1
    
    var normalTexture: MTLTexture?
    var normalMapTiling: Float = 1
    
    var metalness: Float = 0
    var metalnessTexture: MTLTexture?
    
    var roughness: Float = 1
    var roughnessTexture: MTLTexture?
    
    var ambOcclusion: Float = 1
    var ambOcclusionTexture: MTLTexture?
    
    var envMapReflectedAmount: Float = 0
    var envMapRefractedAmount: Float = 0
    var specularExponent: Float = 150
    
    var displacementFactor: Float = 0.15
    var displacementTexture: MTLTexture?
    
    func makeMaterialConstants() -> MaterialConstants {
        MaterialConstants(
            color: color,
            metalness: metalness,
            roughness: roughness,
            ambientOcclusion: ambOcclusion,
            opacity: opacity,
            textureAmount: textureAmount,
            textureTiling: textureTiling,
            normalMapTiling: normalMapTiling,
            envMapReflectedAmount: envMapReflectedAmount,
            envMapRefractedAmount: envMapRefractedAmount,
            specularExponent: specularExponent,
            displacementFactor: displacementFactor)
    }
}
