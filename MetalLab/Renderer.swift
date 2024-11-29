import Foundation
import Metal
import MetalKit
import QuartzCore

typealias TFloat = Float

enum MyError : Error {
    case setup(String)
    case loading(String)
}


class Renderer {
    
    var device: MTLDevice!
    var library: MTLLibrary!
    var mainPipelineState: MTLRenderPipelineState!
    var shadowPipelineState: MTLRenderPipelineState!
    let colorPixelFormat: MTLPixelFormat = .rgba8Unorm;
    var depthStencilState: MTLDepthStencilState!
    var textureSamplerState: MTLSamplerState!
    var commandQueue: MTLCommandQueue!
    
    let sampleCount = 4 // don't use 1 with manual msaa
    let useCustomMsaaRenderPass = true
    var msaaColorTexture: MTLTexture!
    var msaaDepthTexture: MTLTexture!
    
    let depthPixelFormat = MTLPixelFormat.depth32Float
    let winding = MTLWinding.counterClockwise
    let clearColor = MTLClearColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0)
    let clearDepth = 1.0
    let fps = 60
    
    var mtkView: MTKView!
    
    init() { }
    
    var isSetup: Bool {
        return device != nil
    }
    
    @MainActor
    func setupDevice() throws {
        guard let dev = MTLCreateSystemDefaultDevice() else {
            throw MyError.setup("No Device")
        }
        device = dev
    }
    
    @MainActor
    func setMtkView(_ mv: MTKView) throws(MyError) {
        self.mtkView = mv
        mtkView.device = device
        mtkView.clearColor = clearColor
        mtkView.colorPixelFormat = colorPixelFormat
        mtkView.framebufferOnly = true
        mtkView.depthStencilPixelFormat = depthPixelFormat
        mtkView.clearDepth = clearDepth
        mtkView.preferredFramesPerSecond = fps
        mtkView.sampleCount = useCustomMsaaRenderPass ? 1 : sampleCount
        try! setupPipeline()
    }
    
    @MainActor
    func setupPipeline() throws(MyError) {
        
        commandQueue = device.makeCommandQueue()
        guard commandQueue != nil else { throw MyError.setup("No command queue") }
        
        library = device.makeDefaultLibrary()
        if library == nil { throw MyError.setup("no library") }
        guard let vertexFunction = library.makeFunction(name: "vertex_main") else { throw MyError.setup("no vertex shader") }
        guard let fragmentFunction = library.makeFunction(name: "fragment_main") else { throw MyError.setup("no fragment shader") }
        
        let pipelineDesc = MTLRenderPipelineDescriptor()
        pipelineDesc.vertexFunction = vertexFunction
        pipelineDesc.fragmentFunction = fragmentFunction
        
        pipelineDesc.vertexDescriptor = VertexData.vertexDescriptor
        pipelineDesc.colorAttachments[0].pixelFormat = colorPixelFormat
        pipelineDesc.depthAttachmentPixelFormat = depthPixelFormat
        pipelineDesc.rasterSampleCount = sampleCount
        mainPipelineState = try! device.makeRenderPipelineState(descriptor: pipelineDesc)
        
        let samplerDesc = MTLSamplerDescriptor()
        samplerDesc.normalizedCoordinates = true
        samplerDesc.magFilter = .linear
        samplerDesc.minFilter = .linear
        samplerDesc.sAddressMode = .clampToZero
        samplerDesc.tAddressMode = .clampToZero
        textureSamplerState = device.makeSamplerState(descriptor: samplerDesc)
        
        let depthDesc = MTLDepthStencilDescriptor()
        depthDesc.isDepthWriteEnabled = true
        depthDesc.depthCompareFunction = .less
        depthStencilState = device.makeDepthStencilState(descriptor: depthDesc)
        
        // shadow pipeline
        let shadowRPD = MTLRenderPipelineDescriptor()
        shadowRPD.vertexDescriptor = VertexData.vertexDescriptor
        shadowRPD.depthAttachmentPixelFormat = depthPixelFormat
        shadowRPD.vertexFunction = library.makeFunction(name: "vertex_shadow")
        shadowPipelineState = try! device.makeRenderPipelineState(descriptor: shadowRPD)
    }
    
    @MainActor
    func setupMsaaTextures() {
        if sampleCount == 1 { return }
        if mtkView.drawableSize == .zero { return }
        if msaaColorTexture != nil
            && msaaColorTexture.width == Int(mtkView.drawableSize.width)
            && msaaColorTexture.height == Int(mtkView.drawableSize.height)
            && msaaColorTexture.sampleCount == sampleCount
            && msaaDepthTexture != nil
            && msaaDepthTexture.width == Int(mtkView.drawableSize.width)
            && msaaDepthTexture.height == Int(mtkView.drawableSize.height)
            && msaaDepthTexture.sampleCount == sampleCount
        { return }
        
        let colorTexDesc = MTLTextureDescriptor()
        colorTexDesc.textureType = .type2DMultisample
        colorTexDesc.sampleCount = sampleCount
        colorTexDesc.pixelFormat = colorPixelFormat
        colorTexDesc.width = Int(mtkView.drawableSize.width)
        colorTexDesc.height = Int(mtkView.drawableSize.height)
        colorTexDesc.storageMode = .private
        colorTexDesc.usage = .renderTarget
        msaaColorTexture = device.makeTexture(descriptor: colorTexDesc)
        msaaColorTexture.label = "MetalLab: MSAA Color Texture"
        
        let depthTexDesc = MTLTextureDescriptor()
        depthTexDesc.textureType = .type2DMultisample
        depthTexDesc.sampleCount = sampleCount
        depthTexDesc.pixelFormat = depthPixelFormat
        depthTexDesc.width = Int(mtkView.drawableSize.width)
        depthTexDesc.height = Int(mtkView.drawableSize.height)
        depthTexDesc.storageMode = .private
        depthTexDesc.usage = .renderTarget
        msaaDepthTexture = device.makeTexture(descriptor: depthTexDesc)
        msaaDepthTexture.label = "MetalLab: MSAA Depth Texture"
        
    }
    
    @MainActor
    func mainRenderPassDescriptor() -> MTLRenderPassDescriptor {
        if !useCustomMsaaRenderPass {
            return mtkView.currentRenderPassDescriptor!
        }
        // it is necessary to create this descriptor on each frame
        // because mtkView.currentDrawable and it's textures change
        let msaaRenderPassDesc = MTLRenderPassDescriptor()
        msaaRenderPassDesc.colorAttachments[0].texture = msaaColorTexture
        msaaRenderPassDesc.colorAttachments[0].resolveTexture = mtkView.currentDrawable!.texture
        msaaRenderPassDesc.colorAttachments[0].loadAction = .clear
        msaaRenderPassDesc.colorAttachments[0].clearColor = clearColor
        msaaRenderPassDesc.colorAttachments[0].storeAction = .multisampleResolve
        
        msaaRenderPassDesc.depthAttachment.texture = msaaDepthTexture
        msaaRenderPassDesc.depthAttachment.resolveTexture = mtkView.depthStencilTexture
        msaaRenderPassDesc.depthAttachment.loadAction = .clear
        msaaRenderPassDesc.depthAttachment.clearDepth = clearDepth
        msaaRenderPassDesc.depthAttachment.storeAction = .multisampleResolve
        
        return msaaRenderPassDesc
    }
    
    
    @MainActor
    func drawShadowMap(scene: MyScene, cmdBuff: MTLCommandBuffer)
    {
        cmdBuff.pushDebugGroup("Draw Shadow Map")
        
        let shadowRenderPassDesc = MTLRenderPassDescriptor()
        shadowRenderPassDesc.depthAttachment.loadAction = .clear
        shadowRenderPassDesc.depthAttachment.storeAction = .store
        shadowRenderPassDesc.depthAttachment.clearDepth = clearDepth
        shadowRenderPassDesc.depthAttachment.texture = scene.spotLight.texture
        
        let enc = cmdBuff.makeRenderCommandEncoder(descriptor: shadowRenderPassDesc)!
        enc.setFrontFacing(winding)
        enc.setCullMode(.back)
        enc.setRenderPipelineState(shadowPipelineState)
        enc.setDepthStencilState(depthStencilState)
        
        encodeGeometry(scene: scene, encoder: enc)
        
        enc.endEncoding()
        cmdBuff.popDebugGroup()
    }
    
    
    @MainActor
    func drawMain(scene: MyScene, cmdBuff: MTLCommandBuffer) {
        cmdBuff.pushDebugGroup("Main Render Pass")
        let renderPassDesc = mainRenderPassDescriptor()
        guard let enc = cmdBuff.makeRenderCommandEncoder(descriptor: renderPassDesc) else { return }
        
        enc.setFrontFacing(winding)
        enc.setCullMode(.back)
        enc.setRenderPipelineState(mainPipelineState)
        enc.setDepthStencilState(depthStencilState)
        enc.setFragmentSamplerState(textureSamplerState, index: 0)
        
        encodeGeometry(scene: scene, encoder: enc)
        
        enc.endEncoding()
        cmdBuff.popDebugGroup()
    }
    
    func encodeGeometry(scene: MyScene, encoder: MTLRenderCommandEncoder) {
        let projectionMat = scene.camera.projectionMatrix
        let shadowProjectionMat = scene.lightProjectionMatrix
        let viewMat = scene.camera.viewMatrix
        //let viewMat = scene.spotLight.positionOrientation.transform.inverse // render scene from light position
        let directionalLight = scene.directionalLightDir
        let lightMat = scene.spotLight.positionOrientation.transform.inverse
        
        for meshObject in scene.sceneObjects {
            
            // update statics
            let objectStaticData = meshObject.objectStaticDataBuff.contents().bindMemory(to: ObjectStaticData.self, capacity: 1)
            let modelMat = meshObject.positionOrientation.transform
            let modelViewMat = viewMat * modelMat
            
            objectStaticData.pointee.modelViewProjectionMatrix = projectionMat * modelViewMat
            objectStaticData.pointee.modelViewMatrix = modelViewMat
            objectStaticData.pointee.modelViewInverseTransposeMatrix = modelViewMat.inverse.transpose
            objectStaticData.pointee.directionalLightDir = viewMat * directionalLight
            
            let lightPos = viewMat * Float4(scene.spotLight.positionOrientation.position, 1) // position in view space
            let lightDir = viewMat.inverse.transpose * Float4(scene.spotLight.positionOrientation.orientation.axis, 0)
            objectStaticData.pointee.spotLight.position = Float3(lightPos.x, lightPos.y, lightPos.z)
            objectStaticData.pointee.spotLight.direction = Float3(lightDir.x, lightDir.y, lightDir.z)
            objectStaticData.pointee.spotLight.color = scene.spotLight.color
            
            objectStaticData.pointee.modelLightProjectionMatrix = shadowProjectionMat * lightMat * modelMat
            
            if let texture = meshObject.metalMesh.texture {
                encoder.setFragmentTexture(texture, index: 0)
                objectStaticData.pointee.textured = .one
            } else {
                objectStaticData.pointee.textured = .zero
            }
            
            // encode draw calls
            encoder.setVertexBuffer(meshObject.metalMesh.vertexBuffer, offset: 0, index: 0)
            encoder.setVertexBuffer(meshObject.objectStaticDataBuff, offset: 0, index: 1)
            encoder.setFragmentBuffer(meshObject.objectStaticDataBuff, offset: 0, index: 0)
            
            encoder.setFragmentTexture(scene.spotLight.texture, index: 1)
            
            if let indexBuffer = meshObject.metalMesh.indexBuffer {
                encoder.drawIndexedPrimitives(type: .triangle, indexCount: meshObject.metalMesh.indexCount,
                                          indexType: .uint32, indexBuffer: indexBuffer, indexBufferOffset: 0)
            } else {
                encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: meshObject.metalMesh.vertexCount)
            }
        }
        
        // encode instanced geometry
        let instancedMesh = scene.instanceMesh!
        for i in 0..<scene.instanceCount {
            let objectStaticData = scene.instanceStaticsBuff.contents().advanced(by: i * MemoryLayout<ObjectStaticData>.stride)
                                .bindMemory(to: ObjectStaticData.self, capacity: 1)
            
            let modelMat = scene.instancePositions[i].transform
            let modelViewMat = viewMat * modelMat
            objectStaticData.pointee.modelViewProjectionMatrix = projectionMat * modelViewMat
            objectStaticData.pointee.modelViewMatrix = modelViewMat
            objectStaticData.pointee.modelViewInverseTransposeMatrix = modelViewMat.inverse.transpose
            objectStaticData.pointee.directionalLightDir = viewMat * scene.directionalLightDir
            objectStaticData.pointee.modelLightProjectionMatrix = shadowProjectionMat * lightMat * modelMat
            
            let lightPos = viewMat * Float4(scene.spotLight.positionOrientation.position, 1) // in view space
            let lightDir = viewMat.inverse.transpose * Float4(scene.spotLight.positionOrientation.orientation.axis, 0)
            objectStaticData.pointee.spotLight.position = Float3(lightPos.x, lightPos.y, lightPos.z)
            objectStaticData.pointee.spotLight.direction = Float3(lightDir.x, lightDir.y, lightDir.z)
            objectStaticData.pointee.spotLight.color = .one// scene.spotLight.color
            
            if let texture = instancedMesh.metalMesh.texture {
                encoder.setFragmentTexture(texture, index: 0)
                objectStaticData.pointee.textured = .one
            } else {
                objectStaticData.pointee.textured = .zero
            }
        }
        
        // encode draw calls
        encoder.setVertexBuffer(instancedMesh.metalMesh.vertexBuffer, offset: 0, index: 0)
        encoder.setVertexBuffer(scene.instanceStaticsBuff, offset: 0, index: 1)
        // todo: fragment shader will read only the first one, works because it's the same light, transfer data inside shaders
        encoder.setFragmentBuffer(scene.instanceStaticsBuff, offset: 0, index: 0)
        encoder.setFragmentTexture(scene.spotLight.texture, index: 1) // shadow map texture
        
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: instancedMesh.metalMesh.vertexCount, instanceCount: scene.instanceCount)
    }
    
    
    @MainActor
    func drawDepthTexture(scene: MyScene, cmdBuff: MTLCommandBuffer) {
        let pipeline = MTLRenderPipelineDescriptor()
        pipeline.vertexDescriptor = VertexData.vertexDescriptor
        pipeline.vertexFunction = library.makeFunction(name: "vertex_depth_show")
        pipeline.fragmentFunction = library.makeFunction(name: "fragment_depth_show")
        pipeline.colorAttachments[0].pixelFormat = colorPixelFormat
        
        let renderPass = MTLRenderPassDescriptor()
        renderPass.colorAttachments[0].loadAction = .load
        renderPass.colorAttachments[0].clearColor = MTLClearColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0)
        renderPass.colorAttachments[0].texture = mtkView.currentDrawable!.texture
        let pipelineState = try! device.makeRenderPipelineState(descriptor: pipeline)
        
        var vertices: [Float2] = [
            [-1,  1],
            [-1, -1],
            [ 1, -1],
            [-1,  1],
            [ 1, -1],
            [ 1,  1]
        ]
        let aspect = Float(mtkView.drawableSize.width / mtkView.drawableSize.height)
        let wscale = 0.25/aspect
        let scaleMat = float2x2([wscale, 0], [0, 0.25])
        vertices = vertices.map { v in
            scaleMat * v + [-(1-wscale), 0.75]
        }
        let vbuff = device.makeBuffer(bytes: &vertices,length: MemoryLayout<SIMD2<Float>>.stride * vertices.count, options: .storageModeShared)
        
        var uvs: [Float2] = [
            [0.0,  0.0],
            [0.0,  1.0],
            [1.0,  1.0],
            [0.0,  0.0],
            [1.0,  1.0],
            [1.0,  0.0]
        ]
        let uvbuff = device.makeBuffer(bytes: &uvs,length: MemoryLayout<SIMD2<Float>>.stride * uvs.count, options: .storageModeShared)
        
        let enc = cmdBuff.makeRenderCommandEncoder(descriptor: renderPass)!
        enc.setFrontFacing(winding)
        enc.setCullMode(.back)
        enc.setRenderPipelineState(pipelineState)
        enc.setVertexBuffer(vbuff, offset: 0, index: 0)
        enc.setVertexBuffer(uvbuff, offset: 0, index: 1)
        enc.setFragmentSamplerState(textureSamplerState, index: 0)
        enc.setFragmentTexture(scene.spotLight.texture, index: 0)
        enc.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
        enc.endEncoding()
    }
    
    
    @MainActor
    func draw(scene: MyScene) {
        guard let drawable = mtkView.currentDrawable else { return }
        guard let commandBuffer = commandQueue.makeCommandBuffer() else { return }
        
        setupMsaaTextures() // there is no MTKView callback AFTER it changes size
        
        drawShadowMap(scene: scene, cmdBuff: commandBuffer)
        drawMain(scene: scene, cmdBuff: commandBuffer)

        //drawDepthTexture(scene: scene, cmdBuff: commandBuffer)
        
        commandBuffer.present(drawable)
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
    }
}
