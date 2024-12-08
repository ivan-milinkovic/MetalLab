import Foundation
import Metal
import simd

class MyScene {
    
    let camera = Camera()
    var sceneObjects: [MeshObject] = []
    let directionalLightDir: Float3 = [1, -1, -1]
    var spotLight: SpotLight!
    let wind: Wind = .init()
    
    let pool = Pool()
    var isReady = false
    
    var selection: MeshObject!
    var grass: InstancedObject!
    
    var shadowMapProjectionMatrix: float4x4 {
        camera.projectionMatrix
        //let size: Float = 4
        //return float4x4.orthographicProjection(left: -size, right: size, bottom: -size, top: size, near: 1, far: 100)
    }
    
    func updateShear(timeCounter: Double, wind: Wind) {
        let modelMat = grass.position.transform
        var i=0; while i<grass.count { defer { i += 1 }
            let pos = (modelMat * grass.positions[i].position.float4_w1).xyz
            let sample = wind.sample(position: pos, timeCounter: timeCounter)
            grass.positions[i].shear = sample * grass.flexibility[i]
        }
    }
    
    func load(device: MTLDevice) {
        
        let monkey = loadMonkey(device: device)
        monkey.position.moveBy([0, 1.2, -0.5])
        // selection.position.lookAt([0,0, 4]) // todo: fix look at
        monkey.metalMesh.setColor([0.8, 0.4, 0.2, 1])
        self.sceneObjects.append(monkey)
        self.selection = monkey
        
        let planeSize: Float = 4
        let planeMesh = MetalMesh.rectangle(p1: [-planeSize, 0, -planeSize], p2: [planeSize, 0, planeSize], device: device)
        let plane = MeshObject(metalMesh: planeMesh, device: device)
        //plane.metalMesh.texture = MetalMesh.loadPlaceholderTexture(device)
        plane.metalMesh.setColor([0.1, 0.1, 0.05, 1])
        self.sceneObjects.append(plane)
        
        spotLight = SpotLight(device: device)
        spotLight.color = .one // [0.8, 0.8, 1]
        spotLight.position.look(from: [-3, 5, 2.5], at: [0, 0, 0])
        
        self.camera.position.look(from: [0, 1.4, 3.2], at: [0, 1, -2])
        
        makeInstancedBoxes(device)
        makeGrass(device)
        
        isReady = true
    }
    
    func makeInstancedBoxes(_ device: MTLDevice) {
        
        var instancePositions: [Transform] = []
        
        //instancePositions.append(Transform(position: [0, 0.25, 0], scale: 0.25))
        //instancePositions.append(Transform(position: [1, 0.25, 0], scale: 0.25))
        //instancePositions.append(Transform(position: [0, 0.25,-1], scale: 0.25))
        //instancePositions.append(Transform(position: [1, 0.25,-1], scale: 0.25))
        
        let rectSize: Float = 4
        let objectScale: Float = 1.0/8.0
        let densityStep: Float = 0.28
        for i in stride(from: 0, through: rectSize, by: densityStep) {
            for j in stride(from: 0, through: rectSize, by: densityStep) {
                let offset = Float.random(in: -0.1...0.1)
                let scale = objectScale * Float.random(in: 0.5...1.0)
                instancePositions.append(Transform(position: [i + offset, scale, -j + offset], scale: scale))
            }
        }
        
        let metalMesh = pool.loadMesh("box", device: device)
        metalMesh.setColor([0.1, 0.3, 0.8, 1])
        let boxesCluster = InstancedObject(metalMesh: metalMesh, positions: instancePositions, device: device)
        boxesCluster.position.moveBy([-rectSize, 0, 1])
        //metalMesh.texture = MetalMesh.loadPlaceholderTexture(device)
        
        sceneObjects.append(boxesCluster)
    }
    
    func makeGrass(_ device: MTLDevice) {
        var instancePositions: [Transform] = []
        
        let rectSize: Float = 4
        let objectScale: Float = 0.2
        var strandWidth: Float = 0.1
        strandWidth = strandWidth * objectScale * 2 // 0.04
        let offsetLimits = strandWidth * 0.5
        for i in stride(from: 0, through: rectSize, by: strandWidth) {
            for j in stride(from: 0, through: rectSize, by: strandWidth) {
                let offset = Float.random(in: -offsetLimits...offsetLimits)
                let scale = objectScale * Float.random(in: 0.8...1.2)
                instancePositions.append(Transform(position: [i + offset, 0.0, -j + offset], scale: scale))
            }
        }
        
        let mesh = MetalMesh.grassStrand(device)
        let grass = InstancedObject(metalMesh: mesh, positions: instancePositions, device: device)
        //grass.position.moveBy([-rectSize*0.5, 0, 1])
        grass.position.moveBy([0, 0, 1])
        
        for i in 0..<grass.positions.count {
            grass.flexibility[i] = Float.random(in: 0.3...1.0)
        }
        
        sceneObjects.append(grass)
        self.grass = grass
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
