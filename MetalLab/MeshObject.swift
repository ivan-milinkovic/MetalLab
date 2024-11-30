import Metal
import simd

class MeshObject {
    var position: Position = .init()
    let metalMesh: MetalMesh
    var objectStaticDataBuff: MTLBuffer
    
    init(metalMesh: MetalMesh, device: MTLDevice) {
        self.metalMesh = metalMesh
        objectStaticDataBuff = device.makeBuffer(length: MemoryLayout<ObjectConstants>.size, options: .storageModeShared)!
    }
}
