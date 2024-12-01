import Foundation
import Metal
import simd

class MyScene {
    
    let camera = Camera()
    var monkey: MeshObject!
    var sceneObjects: [MeshObject] = []
    let directionalLightDir: Float3 = [1, -1, -1]
    var spotLight: SpotLight!
    
    let pool = Pool()
    
    var shadowMapProjectionMatrix: float4x4 {
        camera.projectionMatrix
        //let size: Float = 4
        //return float4x4.orthographicProjection(left: -size, right: size, bottom: -size, top: size, near: 1, far: 100)
    }
    
    func load(device: MTLDevice) {
        
        let monkey = loadMonkey(device: device)
        monkey.position.moveBy([-1, 1.2, -0.5])
        // monkey.position.lookAt([0,0, 4]) // todo: fix look at
        monkey.metalMesh.setColor([0.8, 0.4, 0.2, 1])
        self.sceneObjects.append(monkey)
        self.monkey = monkey
        
        let planeSize: Float = 4
        let planeMesh = MetalMesh.rectangle(p1: [-planeSize, 0, -planeSize], p2: [planeSize, 0, planeSize], device: device)
        let plane = MeshObject(metalMesh: planeMesh, device: device)
        //plane.metalMesh.texture = MetalMesh.loadPlaceholderTexture(device)
        self.sceneObjects.append(plane)
        
        spotLight = SpotLight(device: device)
        spotLight.color = .one // [0.8, 0.8, 1]
        spotLight.position.look(from: [-3, 5, 2.5], at: [0, 0, 0])
        
        self.camera.position.look(from: [0, 1.4, 3.2], at: [0, 1, -2])
        
        prepareInstances(device)
    }
    
    func prepareInstances(_ device: MTLDevice) {
        let instanceMesh = loadBox(device: device)
        instanceMesh.metalMesh.setColor([0.1, 0.3, 0.8, 1])
        //instanceMesh.metalMesh.texture = MetalMesh.loadPlaceholderTexture(device)
        
        var instancePositions: [Position] = []
        var p = Position()
        p.position = [0, 0.25, 0]
        p.scale = 0.25
        instancePositions.append(p)
        
        p = Position()
        p.position = [1, 0.25, 0]
        p.scale = 0.25
        instancePositions.append(p)
        
        p = Position()
        p.position = [0, 0.25, -1]
        p.scale = 0.25
        instancePositions.append(p)
        
        p = Position()
        p.position = [1, 0.25, -1]
        p.scale = 0.25
        instancePositions.append(p)
        
        let metalMesh = pool.loadMesh("box", device: device)
        let boxesCluster = ClusterObject(metalMesh: metalMesh, positions: instancePositions, device: device)
        sceneObjects.append(boxesCluster)
    }
    
    func loadMonkey(device: MTLDevice) -> MeshObject {
        let metalMesh = pool.loadMesh("monkey", device: device)
        let meshObject = MeshObject(metalMesh: metalMesh, device: device)
        return meshObject
    }
    
    func loadBox(device: MTLDevice) -> MeshObject {
        let metalMesh = pool.loadMesh("box", device: device)
        let meshObject = MeshObject(metalMesh: metalMesh, device: device)
        return meshObject
    }
}
