import Foundation
import Metal
import MetalKit
import QuartzCore


class Renderer {
    
    var device: MTLDevice!
    var library: MTLLibrary!
    var mainPipelineState: MTLRenderPipelineState!
    var shadowPipelineState: MTLRenderPipelineState!
    var envMapPipelineState: MTLRenderPipelineState!
    var updateShearPipelineState: MTLComputePipelineState!
    
    let colorPixelFormat: MTLPixelFormat = .rgba8Unorm;
    //let colorPixelFormat: MTLPixelFormat = .rgba8Unorm_srgb; // automatic gamma-correction
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
    
    var cubeTex: MTLTexture!
    
    var mtkView: MTKView!
    
    var frameConstantsBuff: MTLBuffer!
    
    init() { }
    
    var isSetup: Bool {
        return device != nil
    }
    
    @MainActor
    func setupDevice() throws {
        device = MTLCreateSystemDefaultDevice()!
    }
    
    @MainActor
    func setMtkView(_ mv: MTKView) {
        self.mtkView = mv
        mtkView.device = device
        mtkView.clearColor = clearColor
        mtkView.colorPixelFormat = colorPixelFormat
        mtkView.framebufferOnly = true
        mtkView.depthStencilPixelFormat = depthPixelFormat
        mtkView.clearDepth = clearDepth
        mtkView.preferredFramesPerSecond = fps
        mtkView.sampleCount = useCustomMsaaRenderPass ? 1 : sampleCount
        setupPipeline()
    }
    
    @MainActor
    func setupPipeline() {
        
        commandQueue = device.makeCommandQueue()!
        
        library = device.makeDefaultLibrary()!
        let vertexFunction = library.makeFunction(name: "vertex_main")!
        let fragmentFunction = library.makeFunction(name: "fragment_main")!
        
        let mainPipelineDesc = MTLRenderPipelineDescriptor()
        mainPipelineDesc.vertexFunction = vertexFunction
        mainPipelineDesc.fragmentFunction = fragmentFunction
        
        mainPipelineDesc.vertexDescriptor = VertexData.vertexDescriptor
        mainPipelineDesc.colorAttachments[0].pixelFormat = colorPixelFormat
        mainPipelineDesc.depthAttachmentPixelFormat = depthPixelFormat
        mainPipelineDesc.rasterSampleCount = sampleCount
        mainPipelineDesc.colorAttachments[0].isBlendingEnabled = true
        mainPipelineDesc.colorAttachments[0].sourceRGBBlendFactor = .one
        mainPipelineDesc.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        mainPipelineDesc.colorAttachments[0].rgbBlendOperation = .add
        mainPipelineDesc.colorAttachments[0].sourceAlphaBlendFactor = .one
        mainPipelineDesc.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
        mainPipelineDesc.colorAttachments[0].alphaBlendOperation = .add
        mainPipelineState = try! device.makeRenderPipelineState(descriptor: mainPipelineDesc)
        
        let samplerDesc = MTLSamplerDescriptor()
        samplerDesc.normalizedCoordinates = true
        samplerDesc.magFilter = .linear
        samplerDesc.minFilter = .linear
        samplerDesc.sAddressMode = .repeat
        samplerDesc.tAddressMode = .repeat
        textureSamplerState = device.makeSamplerState(descriptor: samplerDesc)
        
        let depthDesc = MTLDepthStencilDescriptor()
        depthDesc.isDepthWriteEnabled = true
        depthDesc.depthCompareFunction = .lessEqual // set to lessEqual for env map z=1 to work, otherwise use z=0.98, see env. map shader
        depthStencilState = device.makeDepthStencilState(descriptor: depthDesc)

        // shadow pipeline
        let shadowRPD = MTLRenderPipelineDescriptor()
        shadowRPD.vertexDescriptor = VertexData.vertexDescriptor
        shadowRPD.depthAttachmentPixelFormat = depthPixelFormat
        shadowRPD.vertexFunction = library.makeFunction(name: "vertex_shadow")
        shadowPipelineState = try! device.makeRenderPipelineState(descriptor: shadowRPD)
        
        frameConstantsBuff = device.makeBuffer(length: MemoryLayout<FrameConstants>.stride, options: .storageModeShared)
        
        updateShearPipelineState = try! device.makeComputePipelineState(function: library.makeFunction(name: "update_shear")!)
        
        let envPD = MTLRenderPipelineDescriptor()
        envPD.colorAttachments[0].pixelFormat = colorPixelFormat
        envPD.depthAttachmentPixelFormat = depthPixelFormat
        envPD.rasterSampleCount = sampleCount
        envPD.vertexFunction = library.makeFunction(name: "env_map_vertex")!
        envPD.fragmentFunction = library.makeFunction(name: "env_map_fragment")!
        envMapPipelineState = try! device.makeRenderPipelineState(descriptor: envPD)
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
    
    func drawEnvironmentMap(enc: MTLRenderCommandEncoder) {
        
        let fc = frameConstantsBuff.contents().bindMemory(to: FrameConstants.self, capacity: 1)
        var invViewProjectMat = fc.pointee.viewProjectionMatrix.inverse
        
        enc.setRenderPipelineState(envMapPipelineState)
        enc.setFragmentBytes(&invViewProjectMat, length: MemoryLayout<float4x4>.stride, index: 0)
        enc.setFragmentTexture(cubeTex, index: 0)
        enc.setFragmentSamplerState(textureSamplerState, index: 0)
        
        enc.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
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
        enc.setDepthStencilState(depthStencilState)
        
        drawEnvironmentMap(enc: enc)
        
        enc.setRenderPipelineState(mainPipelineState)
        enc.setFragmentSamplerState(textureSamplerState, index: 0)
        
        encodeGeometry(scene: scene, encoder: enc)
        
        enc.endEncoding()
        cmdBuff.popDebugGroup()
    }
    
    func encodeGeometry(scene: MyScene, encoder: MTLRenderCommandEncoder) {
        
        encoder.setVertexBuffer(frameConstantsBuff, offset: 0, index: 2)
        encoder.setFragmentBuffer(frameConstantsBuff, offset: 0, index: 0)
        
        for meshObject in scene.sceneObjects {
            
            meshObject.updateConstantsBuffer()
            let instanceCount = meshObject.instanceCount()
            
            encoder.setVertexBuffer(meshObject.metalMesh.vertexBuffer, offset: 0, index: 0)
            encoder.setVertexBuffer(meshObject.objectConstantsBuff, offset: 0, index: 1)
            encoder.setFragmentTexture(meshObject.metalMesh.texture, index: 0)
            encoder.setFragmentTexture(scene.spotLight.texture, index: 1)
            encoder.setFragmentTexture(cubeTex, index: 2)
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: meshObject.metalMesh.vertexCount, instanceCount: instanceCount)
        }
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
    
    func updateFrameConstants(_ scene: MyScene) {
        let viewMatrix = scene.camera.viewMatrix
        //let viewMatrix = scene.spotLight.transform.transform.inverse // render scene from light perspective
        
        let fc = frameConstantsBuff.contents().bindMemory(to: FrameConstants.self, capacity: 1)
        fc.pointee.viewMatrix = viewMatrix
        fc.pointee.projectionMatrix = scene.camera.projectionMatrix
        fc.pointee.viewProjectionMatrix = fc.pointee.projectionMatrix * fc.pointee.viewMatrix
        
        let dirLight = fc.pointee.viewMatrix * scene.directionalLightDir.float4_w0
        fc.pointee.directionalLightDir = dirLight.xyz
        
        let lightMatrix = scene.spotLight.position.matrix.inverse
        fc.pointee.lightProjectionMatrix = scene.shadowMapProjectionMatrix * lightMatrix
        
        let lightPos = viewMatrix * scene.spotLight.position.position.float4_w1 // position in view space
        let lightDir = viewMatrix.inverse.transpose * scene.spotLight.position.orientation.axis.float4_w0
        fc.pointee.spotLight.position = lightPos.xyz
        fc.pointee.spotLight.direction = lightDir.xyz
        fc.pointee.spotLight.color = scene.spotLight.color
    }
    
    @MainActor
    func draw(scene: MyScene) {
        guard scene.isReady, let drawable = mtkView.currentDrawable, let commandBuffer = commandQueue.makeCommandBuffer()
        else { return }
        
        setupMsaaTextures() // there is no MTKView callback AFTER it changes size
        
        updateFrameConstants(scene)
        
        drawShadowMap(scene: scene, cmdBuff: commandBuffer)
        drawMain(scene: scene, cmdBuff: commandBuffer)

        //drawDepthTexture(scene: scene, cmdBuff: commandBuffer)
        
        commandBuffer.present(drawable)
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
    }
    
}
