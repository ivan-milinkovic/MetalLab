import Foundation
import Metal
import MetalKit

extension Renderer {
    
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
        
        let mainPipelineDesc = MTLRenderPipelineDescriptor()
        mainPipelineDesc.vertexFunction = library.makeFunction(name: "vertex_main")!
        mainPipelineDesc.fragmentFunction = library.makeFunction(name: "fragment_main")!
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
        
        let tessellationPipelineDesc = mainPipelineDesc.copy() as! MTLRenderPipelineDescriptor
        tessellationPipelineDesc.vertexDescriptor = VertexData.tessellationVertexDescriptor
        tessellationPipelineDesc.vertexFunction = library.makeFunction(name: "vertex_tesselation")!
        tessellationPipelineDesc.tessellationFactorFormat = .half
        tessellationPipelineDesc.tessellationPartitionMode = .integer
        tessellationPipelineDesc.tessellationFactorStepFunction = .constant
        tessellationPipelineDesc.tessellationOutputWindingOrder = winding
        tessellationPipelineDesc.tessellationControlPointIndexType = .none // .none when rendering without index buffer
        tesselationPipelineState = try! device.makeRenderPipelineState(descriptor: tessellationPipelineDesc)
        
        let animPipeDesc = mainPipelineDesc.copy() as! MTLRenderPipelineDescriptor
        animPipeDesc.vertexFunction = library.makeFunction(name: "vertex_main_anim")!
        animPipelineState = try! device.makeRenderPipelineState(descriptor: animPipeDesc)
        
        let samplerDesc = MTLSamplerDescriptor()
        samplerDesc.normalizedCoordinates = true
        samplerDesc.magFilter = .linear
        samplerDesc.minFilter = .linear
        samplerDesc.mipFilter = .linear
        samplerDesc.sAddressMode = .repeat
        samplerDesc.tAddressMode = .repeat
        //samplerDesc.maxAnisotropy = 8
        textureSamplerState = device.makeSamplerState(descriptor: samplerDesc)
        
        let depthDesc = MTLDepthStencilDescriptor()
        depthDesc.isDepthWriteEnabled = true
        depthDesc.depthCompareFunction = .lessEqual // set to lessEqual for env map z=1 to work, otherwise use z=0.98, see env. map shader
        depthStencilState = device.makeDepthStencilState(descriptor: depthDesc)

        // shadow pipeline
        let shadowPipelineDesc = MTLRenderPipelineDescriptor()
        shadowPipelineDesc.vertexDescriptor = VertexData.vertexDescriptor
        shadowPipelineDesc.depthAttachmentPixelFormat = depthPixelFormat
        shadowPipelineDesc.vertexFunction = library.makeFunction(name: "vertex_shadow")
        shadowPipelineState = try! device.makeRenderPipelineState(descriptor: shadowPipelineDesc)
        
        let shadowTessPipelineDesc = shadowPipelineDesc.copy() as! MTLRenderPipelineDescriptor
        shadowTessPipelineDesc.vertexDescriptor = VertexData.tessellationVertexDescriptor
        shadowTessPipelineDesc.vertexFunction = library.makeFunction(name: "vertex_shadow_tess")!
        shadowTessPipelineDesc.tessellationFactorFormat = .half
        shadowTessPipelineDesc.tessellationPartitionMode = .integer
        shadowTessPipelineDesc.tessellationFactorStepFunction = .constant
        shadowTessPipelineDesc.tessellationOutputWindingOrder = winding
        shadowTessPipelineDesc.tessellationControlPointIndexType = .none // .none when rendering without index buffer
        shadowTessPipelineState = try! device.makeRenderPipelineState(descriptor: shadowTessPipelineDesc)
        
        
        
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
}
