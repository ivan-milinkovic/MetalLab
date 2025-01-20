import Foundation
import Metal
import MetalKit
import QuartzCore


class Renderer {
    
    var device: MTLDevice!
    var library: MTLLibrary!
    var mainPipelineState: MTLRenderPipelineState!
    var tesselationPipelineState: MTLRenderPipelineState!
    var animPipelineState: MTLRenderPipelineState!
    var shadowPipelineState: MTLRenderPipelineState!
    var shadowTessPipelineState: MTLRenderPipelineState!
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
    var triangleFillMode: MTLTriangleFillMode = .fill
    
    var mtkView: MTKView!
    
    var frameConstantsBuff: MTLBuffer!
    
}
