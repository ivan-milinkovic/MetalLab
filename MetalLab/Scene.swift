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
    var isReady = false
    
    var shadowMapProjectionMatrix: float4x4 {
        camera.projectionMatrix
        //let size: Float = 4
        //return float4x4.orthographicProjection(left: -size, right: size, bottom: -size, top: size, near: 1, far: 100)
    }
    
    func load(device: MTLDevice) {
        
        let monkey = loadMonkey(device: device)
        monkey.position.moveBy([0, 1.2, -0.5])
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
        
        isReady = true
    }
    
    func prepareInstances(_ device: MTLDevice) {
        let instanceMesh = loadBox(device: device)
        instanceMesh.metalMesh.setColor([0.1, 0.3, 0.8, 1])
        //instanceMesh.metalMesh.texture = MetalMesh.loadPlaceholderTexture(device)
        
        var instancePositions: [Position] = []
        
        //instancePositions.append(Position(position: [0, 0.25, 0], scale: 0.25))
        //instancePositions.append(Position(position: [1, 0.25, 0], scale: 0.25))
        //instancePositions.append(Position(position: [0, 0.25,-1], scale: 0.25))
        //instancePositions.append(Position(position: [1, 0.25,-1], scale: 0.25))
        
        let rectSize: Float = 6
        let objectScale: Float = 1.0/8.0
        let densityStep: Float = 0.28
        for i in stride(from: 0, through: rectSize, by: densityStep) {
            for j in stride(from: 0, through: rectSize, by: densityStep) {
                let offset = Float.random(in: -0.1...0.1)
                let scale = objectScale * Float.random(in: 0.5...1.0)
                instancePositions.append(Position(position: [i + offset, scale, -j + offset], scale: scale))
            }
        }
        
        let metalMesh = pool.loadMesh("box", device: device)
        let boxesCluster = ClusterObject(metalMesh: metalMesh, positions: instancePositions, device: device)
        boxesCluster.position.moveBy([-rectSize*0.5, 0, 1])
        
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
