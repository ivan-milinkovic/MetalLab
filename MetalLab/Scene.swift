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
    
    var fileScenes: [FileScene] = []
    var animFileScenes: [FileScene] = []
    var staticFileScenes: [FileScene] = []
    
    let directionalLightDir: Float3 = [1, -1, -1]
    var spotLight: SpotLight!
    let wind: Wind = .init()
    var grass: GrassController!
    var monkey: MeshObject!
    var displacementPlane: MeshObject!
    var simpleAnimMesh: SimpleAnimatedMesh?
    var character: FileScene!
    var helmet: FileScene!
    
    var selection: AnyObject?
    
    var renderer: Renderer!
    var input: Input!
    
    var isReady = false
    
    @MainActor
    func load(device: MTLDevice) {
        
        loadMonkey(device)
        makeFloor(device)
        makeInstancedBoxes(device)
        makeGrass(device)
        makeTransparentPlanes(device: device)
        makeReflectiveCubes(device: device)
        makeNormalMapPlane(device)
        //makeCoordMesh(device)
        loadCharacter(device)
        loadHelmet(device)
        
        loadCubeMap(device: device)
        makeLight(device)
        
        self.camera.transform.look(from: [0, 1.8, 3.2], at: [0, 1, -2])
        splitObjects()
        selection = camera
        simpleAnimMesh?.startAnimation()
        
        isReady = true
    }
    
    func splitObjects() {
        regularObjects = sceneObjects.filter { !$0.shouldTesselate && !$0.hasTransparency }
        tessObjects = sceneObjects.filter { $0.shouldTesselate }
        transparentObjects = sceneObjects.filter { $0.hasTransparency }
        
        animFileScenes = fileScenes.filter { $0.isAnimated }
        staticFileScenes = fileScenes.filter { !$0.isAnimated }
    }
    
    func rotateSelection(dx: Float, dy: Float) {
        switch selection {
        case let camera as Camera:
            camera.transform.rotate2(dx: dx * 0.5, dy: dy * 0.5)
        case let meshObject as MeshObject:
            meshObject.transform.rotate2(dx: dx, dy: dy)
        case let anim as SimpleAnimatedMesh:
            anim.transform.rotate2(dx: dx, dy: dy)
        case let fs as FileScene:
            fs.transform.rotate2(dx: dx, dy: dy)
        default: break
        }
    }
    
    var shadowMapProjectionMatrix: float4x4 {
        camera.projectionMatrix
        //let size: Float = 4
        //return float4x4.orthographicProjection(left: -size, right: size, bottom: -size, top: size, near: 1, far: 100)
    }
    
    func update(dt: Float, timeCounter: Double) {
        updateControls(dt)
        updateMeshObjects()
        simpleAnimMesh?.updateAnim()
        simpleAnimMesh?.updateConstantsBuffer()
        fileScenes.forEach { $0.update() } // Mesh ransforms are updated in Node
        grass.updateShear(timeCounter: timeCounter, wind: wind, characterPos: character?.transform.position)
    }
    
    func updateMeshObjects() {
        let count = sceneObjects.count
        var i = 0; while(i < count) { defer { i += 1}
            sceneObjects[i].updateConstantsBuffer()
        }
    }
    
    func updateControls(_ dt: Float) {
        let fwd = input.forward - input.back
        let right = input.right - input.left
        let up = input.up - input.down
        if abs(fwd) + abs(right) + abs(up) < 0.001 {
            character.animate = false
            return
        }
        
        let speed: Float = 2
        let ds: Float = speed * dt
        
        switch selection {
        case let camera as Camera:
            camera.transform.move(d_forward: fwd*ds, d_right: right*ds, d_up: up*ds)
            
        case let meshObject as MeshObject:
            meshObject.transform.moveBy([right*ds, up*ds, -fwd*ds])
            
        case let anim as SimpleAnimatedMesh:
            anim.transform.moveBy([right*ds, up*ds, -fwd*ds])
            
        case let fs as FileScene:
            fs.moveAsCharacter(dfwd: -fwd*ds, dside: right*ds)
            fs.transform.moveBy([0, up*ds, 0])
            fs.animate = true
            
        default: break
        }
        
        // prevent moving faster diagonally, needs fixing
        //var v = normalize(Float3(fwd, right, up))
        //v *= ds
        //if isnan(v) == [1,1,1] { return }
        //camera.transform.move(d_forward: v.x, d_right: v.y, d_up: v.z)
    }
    
    func loadMonkey(_ device: MTLDevice) {
        let url = Bundle.main.url(forResource: "monkey", withExtension: "obj")!
        let metalMesh = MetalMesh.loadObjFile(url, device: device)
        metalMesh.setColor([0.7, 0.3, 0.14, 1])
        
        let material = Material(color: [0.7, 0.3, 0.14, 1], envMapReflectedAmount: 0.5)
        let monkey = MeshObject(metalMesh: metalMesh, material: material, device: device)
        monkey.transform.scale = 0.5
        monkey.transform.moveBy([-2.2, 1.4, -0.5])
        
        self.monkey = monkey
        self.sceneObjects.append(monkey)
    }
    
    // Max tesselation factor is 16. Large objects with detailed textures need more triangles in the model itself
    func makeNormalMapPlane(_ device: MTLDevice) {
        let url = Bundle.main.url(forResource: "plane", withExtension: "obj")!
        let metalMesh = MetalMesh.loadObjFile(url, device: device)
        let texture = MetalMesh.loadTexture("cobblestone_diffuse.png", srgb: true, device)
        let normalMap = MetalMesh.loadTexture("cobblestone_normals.png", device)
        let displacementMap = MetalMesh.loadTexture("cobblestone_displacement.png", device)
        
        let material = Material(colorTexture: texture, textureAmount: 1.0, normalTexture: normalMap, roughness: 0.5,
                                displacementFactor: 0.15, displacementTexture: displacementMap)
        let plane = MeshObject(metalMesh: metalMesh, material: material, device: device)
        plane.setupTesselationBuffer(tessellationFactor: 16, device: device)
        
        plane.transform.moveBy([-2.5, 0.2, 1.2])
        
        sceneObjects.append(plane)
        displacementPlane = plane
    }
    
    func makeFloor(_ device: MTLDevice) {
        let planeSize: Float = 4
        let planeMesh = MetalMesh.rectangle(p1: [-planeSize, 0, -planeSize], p2: [planeSize, 0, planeSize], device: device)
        
        let material = Material(color: [0.025, 0.025, 0.0125, 1])
        //let texture = MetalMesh.loadTexture("cobblestone_diffuse.png", srgb: true, device)
        //let normalMap = MetalMesh.loadTexture("cobblestone_normals.png", device)
        //let displacementMap = MetalMesh.loadTexture("cobblestone_displacement.png", device)
        //let material = Material(colorTexture: texture, normalTexture: normalMap, textureAmount: 1.0, textureTiling: 2.0, normalMapTiling: 2.0, displacementTexture: displacementMap)
        
        let plane = MeshObject(metalMesh: planeMesh, material: material, device: device)
        plane.setupTesselationBuffer(tessellationFactor: 16, device: device)
        
        self.sceneObjects.append(plane)
    }
    
    func makeLight(_ device: MTLDevice) {
        spotLight = SpotLight(device: device)
        spotLight.color = .one // [0.8, 0.8, 1]
        spotLight.position.look(from: [-3, 5, 2.5], at: [0, 0, 0])
        spotLight.intensity = 4
    }
    
    func makeTransparentPlanes(device: MTLDevice) {
        let material = Material(color: [0.168, 0.28, 0.45, 1], opacity: 0.6)
        let alphaRectMesh = MetalMesh.rectangle(p1: [-1, 0, -1], p2: [1, 0, 0.5], device: device)
        let alphaRect = MeshObject(metalMesh: alphaRectMesh, material: material, device: device)
        alphaRect.transform.moveBy([-1.5, 0.5, 0])
        alphaRect.transform.scale = 0.5
        alphaRect.transform.rotate(dx: .pi * 0.5)
        alphaRect.hasTransparency = true
        
        let alphaRectMesh2 = MetalMesh.rectangle(p1: [-1, 0, -1], p2: [1, 0, 0.5], device: device)
        let alphaRect2 = MeshObject(metalMesh: alphaRectMesh2, material: material, device: device)
        alphaRect2.transform.moveBy([-1.5, 0.5, -0.5])
        alphaRect2.transform.scale = 0.5
        alphaRect2.transform.rotate(dx: .pi * 0.5)
        alphaRect2.hasTransparency = true
        
        // transparent objects need to be sorted from back to front and rendered last
        // for alpha blending to work properly
        self.sceneObjects.append(alphaRect2)
        self.sceneObjects.append(alphaRect)
    }
    
    func makeReflectiveCubes(device: MTLDevice) {
        let scale: Float = 0.2
        let pos = Float3(-2.5, 0.6, 0.5)
        do {
            let url = Bundle.main.url(forResource: "box", withExtension: "obj")!
            let metalMesh = MetalMesh.loadObjFile(url, device: device)
            metalMesh.setColor([0.1, 0.3, 0.8, 1])
            let material = Material(envMapReflectedAmount: 1.0)
            let cube = MeshObject(metalMesh: metalMesh, material: material, device: device)
            cube.transform.scale = scale
            cube.transform.moveBy(pos)
            cube.transform.orientation = simd_quatf(angle: -.pi*0.0, axis: Float3(1, 0, 0))
            sceneObjects.append(cube)
        }
        
        do {
            let url = Bundle.main.url(forResource: "box", withExtension: "obj")!
            let metalMesh = MetalMesh.loadObjFile(url, device: device)
            let material = Material(envMapRefractedAmount: 1.0)
            let cube = MeshObject(metalMesh: metalMesh, material: material, device: device)
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
        let colorTexture = MetalMesh.loadTexture("placeholder2.png", srgb: true, device)
        let material = Material(color: [0.1, 0.3, 0.8, 1], colorTexture: colorTexture, textureAmount: 1.0)
        let boxesCluster = InstancedObject(metalMesh: metalMesh, positions: instancePositions, material: material, device: device)
        boxesCluster.transform.moveBy([-rectSize, 0, 1])
        
        sceneObjects.append(boxesCluster)
    }
    
    func makeGrass(_ device: MTLDevice) {
        self.grass = GrassController.makeGrass(device, commandQueue: renderer.commandQueue)
        sceneObjects.append(grass.grass)
    }
    
    func makeTestTriangle(device: MTLDevice) {
        let triangle: [VertexData] = [
            VertexData(position: [ 0,  1, 0], normal: [0.1, 0.1, 0.1], color: [0.2, 0.2, 0.2, 0.2], uv: [ 0.5,  0.5], tan: [0.8, 0.8, 0.8], btan: [0.9, 0.9, 0.9]), // top
            VertexData(position: [-1, -1, 0], normal: [0.1, 0.1, 0.1], color: [0.2, 0.2, 0.2, 0.2], uv: [ 0.5,  0.5], tan: [0.8, 0.8, 0.8], btan: [0.9, 0.9, 0.9]), // bot left
            VertexData(position: [ 1, -1, 0], normal: [0.1, 0.1, 0.1], color: [0.2, 0.2, 0.2, 0.2], uv: [ 0.5,  0.5], tan: [0.8, 0.8, 0.8], btan: [0.9, 0.9, 0.9]), // bot right, counter-clockwise
        ]
        let mm = MetalMesh(vertices: triangle, device: device)
        let tri = MeshObject(metalMesh: mm, material: Material(), device: device)
        sceneObjects.append(tri)
    }
    
    func loadCubeMap(device: MTLDevice) {
        let size = 2048
        let td = MTLTextureDescriptor()
        td.textureType = .typeCube
        td.pixelFormat = .bgra8Unorm_srgb
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
    
    @MainActor func makeCoordMesh(_ device: MTLDevice) {
        simpleAnimMesh = SimpleAnimatedMesh(device)
        simpleAnimMesh?.transform.scale = 0.3
        simpleAnimMesh?.transform.moveBy([2, 1, 0])
    }
    
    @MainActor func loadCharacter(_ device: MTLDevice) {
        let url = Bundle.main.url(forResource: "Character", withExtension: "usdz")!
        let character = FileScene()
        character.loadScene(url: url, device: device)
        character.transform.scale = 0.3
        character.transform.moveBy([1.25, 0.1, 0])
        
        fileScenes.append(character)
        self.character = character
    }
    
    @MainActor func loadHelmet(_ device: MTLDevice) {
        let url = Bundle.main.url(forResource: "DamagedHelmet", withExtension: "usdz")!
        let helmet = FileScene()
        helmet.loadScene(url: url, device: device)
        helmet.transform.moveBy([0, 1.5, -1])
        
        self.helmet = helmet
        fileScenes.append(helmet)
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

