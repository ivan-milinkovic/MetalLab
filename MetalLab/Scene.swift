import Foundation
import Metal
import simd

class MyScene {
    
    let camera = Camera()
    var monkey: MeshObject!
    var sceneObjects: [MeshObject] = []
    let directionalLightDir: Float4 = [1, -1, -1, 0]
    var spotLight: SpotLight!
    
    var lightProjectionMatrix: float4x4 {
        camera.projectionMatrix
        //let size: Float = 2
        //return float4x4.orthographicProjection(left: -size, right: size, bottom: -size, top: size, near: 1, far: 100)
    }
    
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
        
        spotLight = SpotLight(device: device)
        spotLight.color = .one // [0.8, 0.8, 1]
        spotLight.positionOrientation.look(from: [-2, 4, 2.5], at: [2, 1, 0])
        spotLight.positionOrientation.rotate(dx: -.pi*0.25, dy: -.pi*0.25, dz: 0)
        
        //let rect = MeshObject(metalMesh: MetalMesh.rectangle(device: device), device: device)
        //rect.positionOrientation.rotate(dx: -.pi*0.5)
        //rect.positionOrientation.position = [-2.2, 0.5, 1]
        //rect.positionOrientation.scale = 0.5
        //rect.metalMesh.texture = spotLight.texture // show depth texture in rect
        //sceneObjects.append(rect)
        
        self.camera.positionOrientation.look(from: [0, 1, 4], at: [0, 0, -1])
    }
}
