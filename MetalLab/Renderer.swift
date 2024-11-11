import Foundation
import Metal
import MetalKit
import QuartzCore

typealias TFloat = Float

class Renderer {
    
    var device: MTLDevice!
    var pipelineState: MTLRenderPipelineState!
    let pixelFormat: MTLPixelFormat = .rgba8Unorm;
    var renderPassDesc: MTLRenderPassDescriptor!
    var commandQueue: MTLCommandQueue!
    var constantsBuff: MTLBuffer!
    var mtkView: MTKView!
    
    struct Constants {
        var projectionMatrix: float4x4 = matrix_identity_float4x4
        var viewMatrix: float4x4 = matrix_identity_float4x4
    }
    
    init() { }
    
    var isSetup: Bool {
        return device != nil
    }
    
    @MainActor
    func setup() throws {
        guard let dev = MTLCreateSystemDefaultDevice() else {
            throw MyError.setup("No Device")
        }
        device = dev
        
        commandQueue = device.makeCommandQueue()
        guard commandQueue != nil else { throw MyError.setup("No command queue") }
        
        guard let lib = device.makeDefaultLibrary() else { throw MyError.setup("no library") }
        guard let vertexFunction = lib.makeFunction(name: "basic_vertex") else { throw MyError.setup("no vertex shader") }
        guard let fragmentFunction = lib.makeFunction(name: "basic_fragment") else { throw MyError.setup("no fragment shader") }
        
        let pipelineDesc = MTLRenderPipelineDescriptor()
        pipelineDesc.vertexFunction = vertexFunction
        pipelineDesc.fragmentFunction = fragmentFunction
        pipelineDesc.colorAttachments[0].pixelFormat = pixelFormat
        pipelineDesc.vertexDescriptor = VertexData.vertexDescriptor
        
        constantsBuff = device.makeBuffer(length: MemoryLayout<Constants>.size, options: .storageModeShared)
        
        do {
            pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDesc)
        } catch {
            throw MyError.setup("No pipeline state")
        }
        
        
        renderPassDesc = MTLRenderPassDescriptor()
        renderPassDesc.colorAttachments[0].loadAction = .clear
        renderPassDesc.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
    }
    
    @MainActor
    func setMtkView(_ mv: MTKView) throws(MyError) {
        self.mtkView = mv
        mtkView.device = device
        mtkView.colorPixelFormat = pixelFormat
        mtkView.framebufferOnly = true
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
        
        let constants = constantsBuff.contents().bindMemory(to: Constants.self, capacity: 1)
        constants.pointee.projectionMatrix = projection
    }
    
    @MainActor
    func updateViewMatrix() {
        let rotMat = float4x4(camera.orientation.inverse)
        let transMat = float4x4.init([1,0,0,0], [0,1,0,0], [0,0,1,0], SIMD4(-camera.position, 1))
        let viewMat = transMat * rotMat
        
        let constants = constantsBuff.contents().bindMemory(to: Constants.self, capacity: 1)
        constants.pointee.viewMatrix = viewMat
    }
    
    var meshBuffer: MTLBuffer?
    
    @MainActor
    func draw() {
        guard let drawable = mtkView.currentDrawable else { return }
        guard let vertexBuffer = meshBuffer else { return }
        
        renderPassDesc.colorAttachments[0].texture = drawable.texture
        
        guard let commandBuffer = commandQueue.makeCommandBuffer() else { return }
        
        guard let enc = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDesc) else { return }
        enc.setFrontFacing(.counterClockwise)
        enc.setRenderPipelineState(pipelineState)
        enc.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        enc.setVertexBuffer(constantsBuff, offset: 0, index: 1)
        enc.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        enc.endEncoding()
        
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
    
}

enum MyError : Error {
    case setup(String)
    case loading(String)
}
