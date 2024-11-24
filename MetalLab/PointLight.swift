import Metal

class PointLight {
    var positionOrientation: PositionOrientation = .init()
    var color: Float3 = .one
    let texture: MTLTexture
    
    init(device: MTLDevice) {
        let size = 1024
        let texDesc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .depth32Float, width: size, height: size, mipmapped: false)
        texDesc.storageMode = .private
        texDesc.usage = [.renderTarget, .shaderRead]
        texture = device.makeTexture(descriptor: texDesc)!
    }
}
