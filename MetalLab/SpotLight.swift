import Metal

class SpotLight {
    var position: Transform = .init()
    var color: Float3 = .one
    var intensity: Float = 10
    let texture: MTLTexture
    
    init(device: MTLDevice) {
        let size = 2048 // 1024
        let texDesc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .depth32Float, width: size, height: size, mipmapped: false)
        texDesc.storageMode = .private
        texDesc.usage = [.renderTarget, .shaderRead]
        texture = device.makeTexture(descriptor: texDesc)!
    }
}
