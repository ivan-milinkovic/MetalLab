import Foundation
import Metal
import MetalKit
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
    var grass: AnimatedInstancedObject!
    var monkey: MeshObject!
    var normalMapCube: MeshObject!
    
    var renderer: Renderer!
    
    var shadowMapProjectionMatrix: float4x4 {
        camera.projectionMatrix
        //let size: Float = 4
        //return float4x4.orthographicProjection(left: -size, right: size, bottom: -size, top: size, near: 1, far: 100)
    }
    
    let updateShearOnGpu = true
    
    func updateShear(timeCounter: Double, wind: Wind) {
        if updateShearOnGpu {
            updateShearGpu(timeCounter: timeCounter)
            return
        }
        
        let modelMat = grass.transform.matrix
        let instanceDataPtr = grass.instanceDataBuff.contents().assumingMemoryBound(to: UpdateShearStrandData.self)
        var i=0; while i<grass.count { defer { i += 1 }
            // using buffer for compatibility with the GPU version, see AnimatedInstancedObject.updateConstantsBuffer, it reads from the buffer, not positions
            var data = instanceDataPtr.advanced(by: i).pointee
            
            // sample wind based on world position and update shear
            let pos = (modelMat * data.position.float4_w1).xyz
            let sample = wind.sample(position: pos, timeCounter: timeCounter)
            data.shear = sample * data.flexibility
            
            // calculate the model to world matrix
            let transform = Transform(position: data.position, orientation: simd_quatf(vector: data.orientQuat), scale: data.scale, shear: data.shear)
            data.matrix = modelMat * transform.matrix
            
            // data is a copy, store it back
            instanceDataPtr.advanced(by: i).pointee = data
        }
    }
    
    func updateShearGpu(timeCounter: Double) {
        guard let renderer, grass != nil else { return }
        
        let cmdBuff = renderer.commandQueue.makeCommandBuffer()!
        cmdBuff.pushDebugGroup("Update Shear")
        let enc = cmdBuff.makeComputeCommandEncoder()!
        
        enc.setComputePipelineState(renderer.updateShearPipelineState)
        
        let modelMat = grass.transform.matrix
        
        let shearConstants = grass.instanceConstantsBuff.contents().bindMemory(to: UpdateShearConstants.self, capacity: 1)
        shearConstants.pointee.timeCounter = Float(timeCounter)
        shearConstants.pointee.count = UInt32(grass.count)
        shearConstants.pointee.windStrength = wind.strength
        shearConstants.pointee.windDir = wind.dir
        shearConstants.pointee.containerMat = modelMat
        
        enc.setBuffer(grass.instanceConstantsBuff, offset: 0, index: 0)
        enc.setBuffer(grass.instanceDataBuff, offset: 0, index: 1)
        
        let tnum = 32
        let threadsPerThreadgroup = MTLSize(width: tnum, height: 1, depth: 1)
        let tgCnt = (grass.count / tnum) + 1
        let threadgroupCount = MTLSize(width: tgCnt, height: 1, depth: 1)
        enc.dispatchThreadgroups(threadgroupCount, threadsPerThreadgroup: threadsPerThreadgroup)
        
        enc.endEncoding()
        cmdBuff.popDebugGroup()
        
        cmdBuff.commit()
        cmdBuff.waitUntilCompleted()
    }
    
    func load(device: MTLDevice) {
        
        makeMonkey(device)
        makeFloor(device)
        makeInstancedBoxes(device)
        makeGrass(device)
        makeReflectiveCubes(device: device)
        makeTransparentPlanes(device: device) // transparent objects last
        //makeCubeForNormalMapping(device)
        
        loadCubeMap(device: device)
        makeLight(device)
        
        self.camera.position.look(from: [0, 1.4, 3.2], at: [0, 1, -2])
        
        isReady = true
    }
    
    func makeMonkey(_ device: MTLDevice) {
        let url = Bundle.main.url(forResource: "monkey", withExtension: "obj")!
        let metalMesh = MetalMesh.loadObjFile(url, device: device)
        //metalMesh.texture = MetalMesh.loadPlaceholderTexture(device)
        //metalMesh.normalMap = MetalMesh.loadNormalMapTexture(device)
        metalMesh.setColor([0.8, 0.4, 0.2, 1])
        
        let monkey = MeshObject(metalMesh: metalMesh, device: device)
        monkey.transform.moveBy([0, 1.4, -0.5])
        // selection.transform.lookAt([0,0, 4]) // todo: fix look at
        monkey.setEnvMapReflectedAmount(0.5)
        monkey.setNormalMapTiling(3)
        
        self.monkey = monkey
        self.sceneObjects.append(monkey)        
        self.selection = monkey
    }
    
    func makeCubeForNormalMapping(_ device: MTLDevice) {
        let url = Bundle.main.url(forResource: "box", withExtension: "obj")!
        let metalMesh = MetalMesh.loadObjFile(url, device: device)
        metalMesh.normalMap = MetalMesh.loadNormalMapTexture(device)
        let cube = MeshObject(metalMesh: metalMesh, device: device)
        metalMesh.setColor([0.5, 0.5, 0.5, 1])
        cube.setNormalMapTiling(2)
        cube.transform.scale = 0.3
        cube.transform.moveBy([0, 0, 0.5])
        cube.transform.orientation = simd_quatf(angle: -0.0 * .pi, axis: Float3(0, 1, 0))
        
        //selection = cube
        sceneObjects.append(cube)
        self.normalMapCube = cube
    }
    
    func updateNormalMapping() {
        if monkey.metalMesh.normalMap != nil {
            monkey.metalMesh.normalMap = nil
        } else {
            monkey.metalMesh.normalMap = MetalMesh.loadNormalMapTexture(renderer.device)
        }
    }
    
    func makeFloor(_ device: MTLDevice) {
        let planeSize: Float = 4
        let planeMesh = MetalMesh.rectangle(p1: [-planeSize, 0, -planeSize], p2: [planeSize, 0, planeSize], device: device)
        let plane = MeshObject(metalMesh: planeMesh, device: device)
        //plane.metalMesh.texture = MetalMesh.loadPlaceholderTexture(device)
        plane.metalMesh.setColor([0.1, 0.1, 0.05, 1])
        self.sceneObjects.append(plane)
    }
    
    func makeLight(_ device: MTLDevice) {
        spotLight = SpotLight(device: device)
        spotLight.color = .one // [0.8, 0.8, 1]
        spotLight.position.look(from: [-3, 5, 2.5], at: [0, 0, 0])
    }
    
    func makeTransparentPlanes(device: MTLDevice) {
        let alphaRectMesh = MetalMesh.rectangle(p1: [-1, 0, -1], p2: [1, 0, 0.5], device: device)
        alphaRectMesh.setColor([0.3, 0.5, 0.8, 0.6])
        let alphaRect = MeshObject(metalMesh: alphaRectMesh, device: device)
        alphaRect.transform.moveBy([-1.5, 0.5, 0])
        alphaRect.transform.scale = 0.5
        alphaRect.transform.rotate(dx: .pi * 0.5)
        
        let alphaRectMesh2 = MetalMesh.rectangle(p1: [-1, 0, -1], p2: [1, 0, 0.5], device: device)
        alphaRectMesh2.setColor([0.3, 0.5, 0.8, 0.6])
        let alphaRect2 = MeshObject(metalMesh: alphaRectMesh2, device: device)
        alphaRect2.transform.moveBy([-1.5, 0.5, -1])
        alphaRect2.transform.scale = 0.5
        alphaRect2.transform.rotate(dx: .pi * 0.5)
        
        // transparent objects need to be sorted from back to front
        // for alpha blending to work properly
        self.sceneObjects.append(alphaRect2)
        self.sceneObjects.append(alphaRect)
    }
    
    func makeReflectiveCubes(device: MTLDevice) {
        let scale: Float = 0.2
        let pos = Float3(-2.5, 0.5, 0.5)
        do {
            let metalMesh = pool.loadMesh("box", device: device)
            metalMesh.setColor([0.1, 0.3, 0.8, 1])
            let cube = MeshObject(metalMesh: metalMesh, device: device)
            cube.setEnvMapReflectedAmount(1.0)
            cube.transform.scale = scale
            cube.transform.moveBy(pos)
            cube.transform.orientation = simd_quatf(angle: -.pi*0.0, axis: Float3(1, 0, 0))
            sceneObjects.append(cube)
        }
        
        do {
            let metalMesh = pool.loadMesh("box", device: device)
            metalMesh.setColor([0.1, 0.3, 0.8, 1])
            let cube = MeshObject(metalMesh: metalMesh, device: device)
            cube.setEnvMapRefractedAmount(1.0)
            cube.transform.scale = scale
            cube.transform.moveBy(pos + Float3(2 * scale + 0.1, 0, 0))
            cube.transform.orientation = simd_quatf(angle: -.pi*0.0, axis: Float3(1, 0, 0))
            sceneObjects.append(cube)
        }
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
        boxesCluster.transform.moveBy([-rectSize, 0, 1])
        // metalMesh.texture = MetalMesh.loadPlaceholderTexture(device)
        
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
        let count = instancePositions.count
        
        var flexibility = [Float](repeating: 0, count: count)
        for i in 0..<count {
            flexibility[i] = Float.random(in: 0.3...1.0)
        }
        
        let mesh = MetalMesh.grassStrand(device)
        let grass = AnimatedInstancedObject(metalMesh: mesh, positions: instancePositions, flexibility: flexibility, device: device)
        
        grass.transform.moveBy([0, 0, 1])
        
        sceneObjects.append(grass)
        self.grass = grass
    }
    
    func makeTestTriangle(device: MTLDevice) {
        let triangle: [VertexData] = [
            VertexData(position: [ 0,  1, 0], normal: [0.1, 0.1, 0.1], color: [0.2, 0.2, 0.2, 0.2], uv: [ 0.5,  0.5], tan: [0.8, 0.8, 0.8], btan: [0.9, 0.9, 0.9]), // top
            VertexData(position: [-1, -1, 0], normal: [0.1, 0.1, 0.1], color: [0.2, 0.2, 0.2, 0.2], uv: [ 0.5,  0.5], tan: [0.8, 0.8, 0.8], btan: [0.9, 0.9, 0.9]), // bot left
            VertexData(position: [ 1, -1, 0], normal: [0.1, 0.1, 0.1], color: [0.2, 0.2, 0.2, 0.2], uv: [ 0.5,  0.5], tan: [0.8, 0.8, 0.8], btan: [0.9, 0.9, 0.9]), // bot right, counter-clockwise
        ]
        let mm = MetalMesh(vertices: triangle, texture: nil, device: device)
        let tri = MeshObject(metalMesh: mm, device: device)
        sceneObjects.append(tri)
    }
    
    func loadBox(device: MTLDevice) -> MeshObject {
        let metalMesh = pool.loadMesh("box", device: device)
        let meshObject = MeshObject(metalMesh: metalMesh, device: device)
        return meshObject
    }
        
    func loadCubeMap(device: MTLDevice) {
        let size = 2048
        let td = MTLTextureDescriptor()
        td.textureType = .typeCube
        td.pixelFormat = .bgra8Unorm
        td.width = size
        td.height = size
        td.mipmapLevelCount = 1
        td.usage = .shaderRead
        td.storageMode = .shared
        renderer.cubeTex = device.makeTexture(descriptor: td)!
        
        func cubeFileName(forIndex i: Int) -> String {
            switch i { case 0: "posx"; case 1: "negx"; case 2: "posy"; case 3: "negy"; case 4: "posz"; case 5: "negz"; default: fatalError() }
        }
        let bytesPerRow = size * 4
        let region = MTLRegionMake2D(0, 0, size, size)
        
        for i in 0..<6 {
            let fileName = cubeFileName(forIndex: i)
            let url = Bundle.main.url(forResource: fileName, withExtension: "jpg")!
            
            // extract pixel bytes
            let dp = CGDataProvider(url: url as CFURL)!
            let img = CGImage(jpegDataProviderSource: dp, decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
            var pixelBuff = [UInt8].init(repeating: 0, count: bytesPerRow*size)
            let ctx: CGContext = CGContext(data: &pixelBuff,
                                           width: size,
                                           height: size,
                                           bitsPerComponent: img.bitsPerComponent,
                                           bytesPerRow: bytesPerRow,
                                           space: CGColorSpaceCreateDeviceRGB(),
                                           bitmapInfo: img.bitmapInfo.rawValue)!
            ctx.draw(img, in: CGRect(x: 0, y: 0, width: size, height: size))
            
            // copy into cube map texture
            renderer.cubeTex.replace(region: region, mipmapLevel: 0, slice: i, withBytes: &pixelBuff,
                            bytesPerRow: bytesPerRow, bytesPerImage: 0)
        }
        
        /*
         Alternatively, make a single texture strip, vertical, arranged from top to bottom: +x, -x, +y, -y, +z, -z
         
        let texOpts: [MTKTextureLoader.Option : Any] = [
            .textureUsage : MTLTextureUsage.shaderRead.rawValue,
            .textureStorageMode : MTLStorageMode.private.rawValue,
            .generateMipmaps : true,
            .cubeLayout : MTKTextureLoader.CubeLayout.vertical
        ]
        let url = Bundle.main.url(forResource: "env_map_strip", withExtension: "png")!
        cubeMapTexture = try? textureLoader.newTexture(URL: url, options: texOpts)
         */
    }
}
