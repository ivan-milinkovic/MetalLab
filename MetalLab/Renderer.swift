import Foundation
import Metal
import MetalKit
import QuartzCore

typealias TFloat = Float

class Renderer {
    
    var device: MTLDevice!
    var pipelineState: MTLRenderPipelineState!
    let colorPixelFormat: MTLPixelFormat = .rgba8Unorm;
    var depthStencilState: MTLDepthStencilState!
    var textureSamplerState: MTLSamplerState!
    var commandQueue: MTLCommandQueue!
    var objectStaticDataBuff: MTLBuffer!
    var mtkView: MTKView!
    let depthPixelFormat = MTLPixelFormat.depth32Float
    
    struct ObjectStaticData {
        var modelViewProjectionMatrix: float4x4 = matrix_identity_float4x4
        var modelViewInverseTransposeMatrix: float4x4 = matrix_identity_float4x4
        var textured: SIMD2<Int> = [0,0] // treat as a boolean, boolean and int types have size issues with metal
    }
    
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
        
        guard let lib = device.makeDefaultLibrary() else { throw MyError.setup("no library") }
        guard let vertexFunction = lib.makeFunction(name: "vertex_main") else { throw MyError.setup("no vertex shader") }
        guard let fragmentFunction = lib.makeFunction(name: "fragment_main") else { throw MyError.setup("no fragment shader") }
        
        let pipelineDesc = MTLRenderPipelineDescriptor()
        pipelineDesc.vertexFunction = vertexFunction
        pipelineDesc.fragmentFunction = fragmentFunction
        
        pipelineDesc.vertexDescriptor = VertexData.vertexDescriptor
        pipelineDesc.colorAttachments[0].pixelFormat = colorPixelFormat
        pipelineDesc.depthAttachmentPixelFormat = depthPixelFormat
        pipelineDesc.rasterSampleCount = mtkView.sampleCount
        
        objectStaticDataBuff = device.makeBuffer(length: MemoryLayout<ObjectStaticData>.size, options: .storageModeShared)
        
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
    }
    
    func updateObjectStaticData(projectionMat: float4x4, viewMat: float4x4, modelMat: float4x4, texture: (any MTLTexture)?, encoder: MTLRenderCommandEncoder) {
        let objectStaticData = objectStaticDataBuff.contents().bindMemory(to: ObjectStaticData.self, capacity: 1)
        let viewModelMat = viewMat * modelMat
        objectStaticData.pointee.modelViewProjectionMatrix = projectionMat * viewModelMat
        objectStaticData.pointee.modelViewInverseTransposeMatrix = viewModelMat.inverse.transpose
        
        if let texture = texture {
            encoder.setFragmentTexture(texture, index: 0)
            objectStaticData.pointee.textured = .one
        } else {
            objectStaticData.pointee.textured = .zero
        }
    }
    
    var camera: Camera!
    var mesh: MyMesh?
    
    @MainActor
    func draw() {
        guard let drawable = mtkView.currentDrawable else { return }
        guard let mesh = mesh else { return }
        guard let renderPassDesc = mtkView.currentRenderPassDescriptor else { return }
        guard let commandBuffer = commandQueue.makeCommandBuffer() else { return }
        guard let enc = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDesc) else { return }
        
        updateObjectStaticData(projectionMat: camera.projectionMatrix,
                               viewMat: camera.viewMatrix,
                               modelMat: mesh.transform,
                               texture: mesh.texture,
                               encoder: enc)
        
        enc.setRenderPipelineState(pipelineState)
        enc.setDepthStencilState(depthStencilState)
        
        enc.setFrontFacing(.counterClockwise)
        enc.setCullMode(.back)
        
        enc.setVertexBuffer(mesh.vertexBuffer, offset: 0, index: 0)
        enc.setFragmentSamplerState(textureSamplerState, index: 0)
        
        enc.setVertexBuffer(objectStaticDataBuff, offset: 0, index: 1)
        
        if let indexBuffer = mesh.indexBuffer {
            enc.drawIndexedPrimitives(type: .triangle, indexCount: mesh.indexCount, indexType: .uint32, indexBuffer: indexBuffer, indexBufferOffset: 0)
        } else {
            enc.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: mesh.vertexCount)
        }
        
        enc.endEncoding()
        
        commandBuffer.present(drawable)
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
    }
    
}

enum MyError : Error {
    case setup(String)
    case loading(String)
}
