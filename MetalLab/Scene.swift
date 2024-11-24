import Foundation
import Metal
import simd

class MyScene {
    
    let camera = Camera()
    var sceneObject: MeshObject!
    let directionalLightDir: Float4 = [1, -1, -1, 0]
    
    func load(device: MTLDevice) {
        //mesh = MyMesh.triangle(device: device)
        //mesh = MyMesh.rectangle(device: device)
        let metalMesh = MetalMesh.monkey(device: device)
        sceneObject = MeshObject(metalMesh: metalMesh)
        sceneObject.positionOrientation.rotate(dx: -.pi*0.5, dy: 0)
        
        camera.positionOrientation.position = [0, 0, 4]
        camera.positionOrientation.orientation = simd_quatf(angle: 0.0, axis: [0, 0, -1])
    }
}
