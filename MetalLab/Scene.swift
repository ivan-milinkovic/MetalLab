import Foundation
import Metal
import MetalKit
import simd

class MyScene {
    
    let camera = Camera()
    
    var sceneObjects: [MeshObject] = []
    var regularObjects: [MeshObject] = []
    var tessObjects: [MeshObject] = []
    var transparentObjects: [MeshObject] = []
    
    let directionalLightDir: Float3 = [1, -1, -1]
    var spotLight: SpotLight!
    let wind: Wind = .init()
    
    let pool = Pool()
    var isReady = false
    
    var selection: AnyObject?
    var grass: AnimatedInstancedObject!
    var monkey: MeshObject!
    var normalMapPlane: MeshObject!
    var animMesh: AnimatedMesh!
    var fileScene: FileScene!
    
    var renderer: Renderer!
    var input: Input!
    
    let updateShearOnGpu = true
    
    @MainActor
    func load(device: MTLDevice) {
        
        makeMonkey(device)
        makeFloor(device)
        makeInstancedBoxes(device)
        makeGrass(device)
        makeTransparentPlanes(device: device)
        makeReflectiveCubes(device: device)
        makeNormalMapPlane(device)
        makeAnimatedMesh(device)
        makeFileScene(device)
        
        loadCubeMap(device: device)
        makeLight(device)
        
        self.camera.transform.look(from: [0, 1.4, 3.2], at: [0, 1, -2])
        splitObjects()
        selection = camera
        animMesh.startAnimation()
        
        isReady = true
    }
    
    func splitObjects() {
        regularObjects = sceneObjects.filter { !$0.shouldTesselate && !$0.hasTransparency }
        tessObjects = sceneObjects.filter { $0.shouldTesselate }
        transparentObjects = sceneObjects.filter { $0.hasTransparency }
    }
    
    func rotateSelection(dx: Float, dy: Float) {
        switch selection {
        case let camera as Camera:
            camera.transform.rotate2(dx: dx * 0.5, dy: dy * 0.5)
        case let meshObject as MeshObject:
            meshObject.transform.rotate2(dx: dx, dy: dy)
        case let anim as AnimatedMesh:
            anim.transform.rotate2(dx: dx, dy: dy)
        default: break
        }
    }
    
    var shadowMapProjectionMatrix: float4x4 {
        camera.projectionMatrix
        //let size: Float = 4
        //return float4x4.orthographicProjection(left: -size, right: size, bottom: -size, top: size, near: 1, far: 100)
    }
    
    func update(dt: Float, timeCounter: Double) {
        updateControls()
        updateShear(timeCounter: timeCounter, wind: wind)
        animMesh.updateAnim()
        fileScene.update()
    }
    
    func updateControls() {
        let fwd = input.forward - input.back
        let right = input.right - input.left
        let up = input.up - input.down
        let ds: Float = 0.05
        camera.transform.move(d_forward: fwd*ds, d_right: right*ds, d_up: up*ds)
        
        // prevent moving faster diagonally, needs fixing
        //var v = normalize(Float3(fwd, right, up))
        //v *= ds
        //if isnan(v) == [1,1,1] { return }
        //camera.transform.move(d_forward: v.x, d_right: v.y, d_up: v.z)
    }
    
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
    
    func makeMonkey(_ device: MTLDevice) {
        let url = Bundle.main.url(forResource: "monkey", withExtension: "obj")!
        let metalMesh = MetalMesh.loadObjFile(url, device: device)
        metalMesh.setColor([0.8, 0.4, 0.2, 1])
        
        let monkey = MeshObject(metalMesh: metalMesh, device: device)
        monkey.transform.moveBy([0, 1.4, -0.5])
        // selection.transform.lookAt([0,0, 4]) // todo: fix look at
        monkey.setEnvMapReflectedAmount(0.5)
        monkey.setNormalMapTiling(3)
        
        self.monkey = monkey
        self.sceneObjects.append(monkey)
    }
    
    // Max tesselation factor is 16. Large objects with detailed textures need more triangles in the model itself
    func makeNormalMapPlane(_ device: MTLDevice) {
        let url = Bundle.main.url(forResource: "plane", withExtension: "obj")!
        let metalMesh = MetalMesh.loadObjFile(url, device: device)
        metalMesh.texture = MetalMesh.loadTexture("cobblestone_diffuse.png", device)
        metalMesh.normalMap = MetalMesh.loadTexture("cobblestone_normals.png", device)
        metalMesh.displacementMap = MetalMesh.loadTexture("cobblestone_displacement.png", device)
        
        let plane = MeshObject(metalMesh: metalMesh, device: device)
        plane.setupTesselationBuffer(tessellationFactor: 16, device: device)
        plane.setDisplacementFactor(0.15)
        
        plane.transform.rotate2(dx: 0.5 * .pi)
        plane.transform.moveBy([-2.5, 1.5, -1.2])
        //plane.transform.moveBy([0, 0.5, 0.0])
        
        sceneObjects.append(plane)
        normalMapPlane = plane
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
        alphaRect.hasTransparency = true
        
        let alphaRectMesh2 = MetalMesh.rectangle(p1: [-1, 0, -1], p2: [1, 0, 0.5], device: device)
        alphaRectMesh2.setColor([0.3, 0.5, 0.8, 0.6])
        let alphaRect2 = MeshObject(metalMesh: alphaRectMesh2, device: device)
        alphaRect2.transform.moveBy([-1.5, 0.5, -1])
        alphaRect2.transform.scale = 0.5
        alphaRect2.transform.rotate(dx: .pi * 0.5)
        alphaRect2.hasTransparency = true
        
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
        
        let url = Bundle.main.url(forResource: "box", withExtension: "obj")!
        let metalMesh = MetalMesh.loadObjFile(url, device: device)
        metalMesh.setColor([0.1, 0.3, 0.8, 1])
        let boxesCluster = InstancedObject(metalMesh: metalMesh, positions: instancePositions, device: device)
        boxesCluster.transform.moveBy([-rectSize, 0, 1])
        metalMesh.texture = MetalMesh.loadPlaceholderTexture(device)
        
        sceneObjects.append(boxesCluster)
    }
    
    func makeGrass(_ device: MTLDevice) {
        
        let url = Bundle.main.url(forResource: "perlin", withExtension: "png")!
        let dp = CGDataProvider(url: url as CFURL)!
        let img = CGImage(pngDataProviderSource: dp, decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
        let bytesPerPixel = img.bitsPerPixel / img.bitsPerComponent
        let bytesPerRow = img.bytesPerRow
        let perlinSize = img.width // expects rectangular image
        
        // Have to copy the bytes, otherwise there are issues getting wrong values when using CFDataGetBytePtr(img.dataProvider!.data!)!
        var perlinBytes = [UInt8].init(repeating: 0, count: bytesPerRow*perlinSize)
        let ctx: CGContext = CGContext(data: &perlinBytes,
                                       width: perlinSize,
                                       height: perlinSize,
                                       bitsPerComponent: img.bitsPerComponent,
                                       bytesPerRow: bytesPerRow,
                                       space: CGColorSpaceCreateDeviceGray(),
                                       bitmapInfo: img.bitmapInfo.rawValue)!
        ctx.draw(img, in: CGRect(x: 0, y: 0, width: perlinSize, height: perlinSize))
        
        var instancePositions: [Transform] = []
        
        let rectSize: Float = 4
        let objectScale: Float = 0.2
        var strandWidth: Float = 0.1
        strandWidth = strandWidth * objectScale * 2 // 0.04
        let offsetLimits = strandWidth * 0.5
        let perlinUvScale: Float = 2
        
        for iy in stride(from: 0, through: rectSize, by: strandWidth) {
            for ix in stride(from: 0, through: rectSize, by: strandWidth) {
                // position jitter
                let posOffset = Float.random(in: -offsetLimits...offsetLimits)
                
                let orientation = simd_quatf(angle: Float.random(in: 0.0...0.2) * .pi, axis: [0, 1, 0])
                
                // scale from noise and jitter
                // proportional mapping: how far are we through the grass area rectangle - same proportion index into perlin
                let perlinX_ = (ix / rectSize) * Float(perlinSize)
                let perlinY_ = (iy / rectSize) * Float(perlinSize)
                // scale and wrap around perlin texture coordinates
                let perlinX = Int(perlinX_ * perlinUvScale) % perlinSize
                let perlinY = Int(perlinY_ * perlinUvScale) % perlinSize
                let ind = perlinY * bytesPerRow + perlinX * bytesPerPixel
                let perlinScale = Float(perlinBytes[ind]) / 255.0
                let scale = (objectScale * Float.random(in: 0.8...1.2)) + (perlinScale * 0.16)
                //let scale = perlinScale * 0.3 // visualize perlin
                
                // make
                instancePositions.append(Transform(position: [ix + posOffset, 0.0, -iy + posOffset], orientation: orientation, scale: scale))
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
    
    @MainActor func makeAnimatedMesh(_ device: MTLDevice) {
        animMesh = AnimatedMesh(device)
        animMesh.transform.scale = 0.3
        animMesh.transform.moveBy([2, 1, 0])
    }
    
    @MainActor func makeFileScene(_ device: MTLDevice) {
        fileScene = FileScene()
        fileScene.loadTestScene(device)
        fileScene.transform.scale = 0.5
        fileScene.transform.moveBy([1.25, 1, 0])
    }
}

/// Make color space by: `CGColorSpace(name: CGColorSpace.linearGray)!`
func cgImage(_ px: UnsafeRawPointer, w: Int, h: Int, bytesPerPixel: Int, colorSpace: CGColorSpace, alphaInfo: CGImageAlphaInfo) -> CGImage {
    let cgDataProvider = CGDataProvider(data: NSData(bytes: px, length: w * h * bytesPerPixel))!
    let cgImage = CGImage(width: w,
                          height: h,
                          bitsPerComponent: 8,
                          bitsPerPixel: 8,
                          bytesPerRow: w*bytesPerPixel,
                          space: colorSpace,
                          bitmapInfo: CGBitmapInfo(rawValue: alphaInfo.rawValue),
                          provider: cgDataProvider,
                          decode: nil,
                          shouldInterpolate: false,
                          intent: CGColorRenderingIntent.defaultIntent)!
    return cgImage
}

