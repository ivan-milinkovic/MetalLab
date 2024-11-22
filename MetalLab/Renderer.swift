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
    var constantsBuff: MTLBuffer!
    var mtkView: MTKView!
    let depthPixelFormat = MTLPixelFormat.depth32Float
    
    struct FrameConstants {
        var projectionMatrix: float4x4 = matrix_identity_float4x4
        var viewMatrix: float4x4 = matrix_identity_float4x4
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
        
        constantsBuff = device.makeBuffer(length: MemoryLayout<FrameConstants>.size, options: .storageModeShared)
        
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
    
    var camera: Camera!
    
    @MainActor
    func update() {
        updateProjection()
        updateViewMatrix()
    }
    
    @MainActor
    func updateProjection() {
        let fovRads: TFloat = 60 * TFloat.pi / 180.0
        let near: TFloat = 1.0
        let far: TFloat = 100.0
        let aspect = TFloat(mtkView.drawableSize.width / mtkView.drawableSize.height)
        
        // right-handed
        let Sy = 1 / tan(fovRads * 0.5)
        let Sx = Sy / aspect
        let dz = far - near
        let Sz = -(far + near) / dz
        let Tz = -2 * (far * near) / dz
        let projection = float4x4(
            SIMD4(Sx, 0,  0,  0),
            SIMD4(0, Sy,  0,  0),
            SIMD4(0,  0, Sz, -1),
            SIMD4(0,  0,  Tz, 0)
        )
        
        let constants = constantsBuff.contents().bindMemory(to: FrameConstants.self, capacity: 1)
        constants.pointee.projectionMatrix = projection
    }
    
    @MainActor
    func updateViewMatrix() {
        let rotMat = float4x4(camera.orientation.inverse)
        let transMat = float4x4.init([1,0,0,0], [0,1,0,0], [0,0,1,0], SIMD4(-camera.position, 1))
        let viewMat = transMat * rotMat
        
        let constants = constantsBuff.contents().bindMemory(to: FrameConstants.self, capacity: 1)
        constants.pointee.viewMatrix = viewMat
    }
    
    var mesh: MyMesh?
    
    @MainActor
    func draw() {
        guard let drawable = mtkView.currentDrawable else { return }
        guard let mesh = mesh else { return }
        guard let renderPassDesc = mtkView.currentRenderPassDescriptor else { return }
        
        guard let commandBuffer = commandQueue.makeCommandBuffer() else { return }
        guard let enc = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDesc) else { return }
        
        enc.setRenderPipelineState(pipelineState)
        enc.setDepthStencilState(depthStencilState)
        
        enc.setFrontFacing(.counterClockwise)
        enc.setCullMode(.back)
        
        enc.setVertexBuffer(mesh.vertexBuffer, offset: 0, index: 0)
        let constants = constantsBuff.contents().bindMemory(to: FrameConstants.self, capacity: 1)
        if let texture = mesh.texture {
            enc.setFragmentTexture(texture, index: 0)
            constants.pointee.textured = .one
        } else {
            constants.pointee.textured = .zero
        }
        
        enc.setFragmentSamplerState(textureSamplerState, index: 0)
        
        enc.setVertexBuffer(constantsBuff, offset: 0, index: 1)
        
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
