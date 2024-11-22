import Foundation
import Metal
import simd

class MyScene {
    
    let camera = Camera()
    var mesh: MyMesh!
    let directionalLightDir: Float4 = [1, -1, -1, 0]
    
    func load(device: MTLDevice) {
        //mesh = MyMesh.triangle(device: device)
        //mesh = MyMesh.rectangle(device: device)
        mesh = MyMesh.monkey(device: device)
        mesh.rotate(dx: -.pi*0.5, dy: 0)
    }
}
