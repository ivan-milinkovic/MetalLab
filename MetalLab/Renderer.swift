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
    var pipelineState: MTLRenderPipelineState!
    var shadowPipelineState: MTLRenderPipelineState!
    let colorPixelFormat: MTLPixelFormat = .rgba8Unorm;
    var depthStencilState: MTLDepthStencilState!
    var textureSamplerState: MTLSamplerState!
    var commandQueue: MTLCommandQueue!
    var mtkView: MTKView!
    let depthPixelFormat = MTLPixelFormat.depth32Float
    let winding = MTLWinding.counterClockwise
    
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
        mtkView.clearColor = MTLClearColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0)
        mtkView.colorPixelFormat = colorPixelFormat
        mtkView.framebufferOnly = true
        mtkView.depthStencilPixelFormat = depthPixelFormat
        mtkView.clearDepth = 1.0
        mtkView.preferredFramesPerSecond = 60
        mtkView.sampleCount = 1
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
        pipelineDesc.rasterSampleCount = mtkView.sampleCount
        
        do {
            pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDesc)
        } catch {
            throw MyError.setup("No pipeline state")
        }
        
        let samplerDesc = MTLSamplerDescriptor()
        samplerDesc.normalizedCoordinates = true
        samplerDesc.magFilter = .linear
        samplerDesc.minFilter = .linear
        samplerDesc.sAddressMode = .repeat
        samplerDesc.tAddressMode = .repeat
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
    func drawShadowMap(scene: MyScene, cmdBuff: MTLCommandBuffer)
    {
        let rpd = MTLRenderPassDescriptor()
        rpd.depthAttachment.loadAction = .clear
        rpd.depthAttachment.storeAction = .store
        rpd.depthAttachment.clearDepth = 1.0
        rpd.depthAttachment.texture = scene.spotLight.texture
        
        //cmdBuff.pushDebugGroup("Draw Shadow Map")
        //cmdBuff.popDebugGroup()
        
        let enc = cmdBuff.makeRenderCommandEncoder(descriptor: rpd)!
        enc.setRenderPipelineState(shadowPipelineState)
        enc.setDepthStencilState(depthStencilState)
        enc.setFrontFacing(winding)
        enc.setCullMode(.back)
        
        let projectionMat = scene.lightProjectionMatrix
        let lightMat = scene.spotLight.positionOrientation.transform.inverse
        
        for meshObject in scene.sceneObjects {
            // update statics
            let objectStatics = meshObject.objectStaticDataBuff.contents().bindMemory(to: ObjectStaticData.self, capacity: 1)
            let modelMat = meshObject.positionOrientation.transform
            objectStatics.pointee.modelLightProjectionMatrix = projectionMat * lightMat * modelMat
            
            // encode draw calls
            for meshObject in scene.sceneObjects {
                enc.setVertexBuffer(meshObject.metalMesh.vertexBuffer, offset: 0, index: 0)
                enc.setVertexBuffer(meshObject.objectStaticDataBuff, offset: 0, index: 1)
                if let indexBuffer = meshObject.metalMesh.indexBuffer {
                    enc.drawIndexedPrimitives(type: .triangle, indexCount: meshObject.metalMesh.indexCount,
                                              indexType: .uint32, indexBuffer: indexBuffer, indexBufferOffset: 0)
                } else {
                    enc.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: meshObject.metalMesh.vertexCount)
                }
            }
        }
        
        enc.endEncoding()
    }
    
    
    @MainActor
    func draw(scene: MyScene, cmdBuff: MTLCommandBuffer) {
        guard let renderPassDesc = mtkView.currentRenderPassDescriptor else { return }
        guard let enc = cmdBuff.makeRenderCommandEncoder(descriptor: renderPassDesc) else { return }
        
        enc.setFrontFacing(winding)
        enc.setCullMode(.back)
        enc.setRenderPipelineState(pipelineState)
        enc.setDepthStencilState(depthStencilState)
        enc.setFragmentSamplerState(textureSamplerState, index: 0)
        
        let viewMat = scene.camera.viewMatrix
        //let viewMat = scene.spotLight.positionOrientation.transform.inverse // view from light position
        let projectionMat = scene.camera.projectionMatrix
        let directionalLight = scene.directionalLightDir
        
        for meshObject in scene.sceneObjects {
            
            // update statics
            let objectStaticData = meshObject.objectStaticDataBuff.contents().bindMemory(to: ObjectStaticData.self, capacity: 1)
            let modelMat = meshObject.positionOrientation.transform
            let modelViewMat = viewMat * modelMat
            
            objectStaticData.pointee.modelViewProjectionMatrix = projectionMat * modelViewMat
            objectStaticData.pointee.modelViewMatrix = modelViewMat
            objectStaticData.pointee.modelMatrix = modelMat
            objectStaticData.pointee.modelViewInverseTransposeMatrix = modelViewMat.inverse.transpose
            objectStaticData.pointee.directionalLightDir = viewMat * directionalLight
            
            let lightPos = viewMat * Float4(scene.spotLight.positionOrientation.position, 1) // position in view space
            let lightDir = viewMat.inverse.transpose * Float4(scene.spotLight.positionOrientation.orientation.axis, 0)
            objectStaticData.pointee.spotLight.position = Float3(lightPos.x, lightPos.y, lightPos.z)
            objectStaticData.pointee.spotLight.direction = Float3(lightDir.x, lightDir.y, lightDir.z)
            objectStaticData.pointee.spotLight.color = scene.spotLight.color
            
            if let texture = meshObject.metalMesh.texture {
                enc.setFragmentTexture(texture, index: 0)
                objectStaticData.pointee.textured = .one
            } else {
                objectStaticData.pointee.textured = .zero
            }
            
            
            // encode draw calls
            enc.setVertexBuffer(meshObject.metalMesh.vertexBuffer, offset: 0, index: 0)
            enc.setVertexBuffer(meshObject.objectStaticDataBuff, offset: 0, index: 1)
            enc.setFragmentBuffer(meshObject.objectStaticDataBuff, offset: 0, index: 0)
            
            enc.setFragmentTexture(scene.spotLight.texture, index: 1)
            
            if let indexBuffer = meshObject.metalMesh.indexBuffer {
                enc.drawIndexedPrimitives(type: .triangle, indexCount: meshObject.metalMesh.indexCount,
                                          indexType: .uint32, indexBuffer: indexBuffer, indexBufferOffset: 0)
            } else {
                enc.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: meshObject.metalMesh.vertexCount)
            }
        }
        
        enc.endEncoding()
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
        
        drawShadowMap(scene: scene, cmdBuff: commandBuffer)
        draw(scene: scene, cmdBuff: commandBuffer)
        //drawDepthTexture(scene: scene, cmdBuff: commandBuffer)
        
        commandBuffer.present(drawable)
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
    }
}
