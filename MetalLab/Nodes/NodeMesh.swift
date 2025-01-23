import Metal
import MetalKit
import ModelIO

/// Easier access to mesh properties and conversion from MDL to MTK models
struct NodeMesh {
    let mesh: MDLMesh
    let submeshes: [MDLSubmesh]
    let objectConstantsBuff: MTLBuffer
    let mtkMeshBuffer: MTKMeshBuffer
}
