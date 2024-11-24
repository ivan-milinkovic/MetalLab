import Foundation
import Metal
import simd

class MyScene {
    
    let camera = Camera()
    var monkey: MeshObject!
    var sceneObjects: [MeshObject] = []
    let directionalLightDir: Float4 = [1, -1, -1, 0]
    
    func load(device: MTLDevice) {
        //let triangle = MeshObject(metalMesh: MetalMesh.triangle(device: device), device: device)
        //triangle.positionOrientation.position = [0,1,0]
        //sceneObjects.append(triangle)
        
        let metalMesh = MetalMesh.monkey(device: device)
        let monkey = MeshObject(metalMesh: metalMesh, device: device)
        monkey.positionOrientation.rotate(dx: .pi*0.5, dy: 0)
        monkey.positionOrientation.moveBy([0, 1.2, 0])
        self.sceneObjects.append(monkey)
        self.monkey = monkey
        
        let planeSize: Float = 4
        let planeMesh = MetalMesh.rectangle(p1: [-planeSize, 0, -planeSize], p2: [planeSize, 0, planeSize], device: device)
        let plane = MeshObject(metalMesh: planeMesh, device: device)
        self.sceneObjects.append(plane)
        
        self.camera.positionOrientation.look(from: [0, 1, 4], at: [0, 0, -1])
    }
}
