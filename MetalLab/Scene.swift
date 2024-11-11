import Foundation
import Metal
import simd

class MyScene {
    
    let camera = Camera()
    var mesh: MyMesh!
    
    func load(device: MTLDevice) {
//        mesh = MyMesh.triangle(device: device)
        mesh = MyMesh.rectangle(device: device)
    }
}
