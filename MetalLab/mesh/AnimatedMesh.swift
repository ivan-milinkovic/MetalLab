import Foundation
import Metal
import ModelIO
import MetalKit

class AnimatedMesh {
    let mtkVertexBuffer: MTKMeshBuffer
    let mtkIndexBuffer: MTKMeshBuffer
    
    let skeleton: MDLSkeleton
    let animation: MDLPackedJointAnimation
    
    var objectConstantsBuff: MTLBuffer
    let geometryType: MTLPrimitiveType
    let indexType: MTLIndexType
    let indexCount: Int
    
    @MainActor
    init(_ device: MTLDevice) {
        let allocator = MTKMeshBufferAllocator(device: device)
        let url = Bundle.main.url(forResource: "butterfly", withExtension: "usda")!
        let asset = MDLAsset(url: url, vertexDescriptor: VertexData.makeModelioVertexDescriptor(), bufferAllocator: allocator)
        let bonesObj = asset.childObjects(of: MDLObject.self).first(where: { $0.name == "bones_object" })!
        let animationBinding = bonesObj.components.first { $0 is MDLAnimationBindComponent } as! MDLAnimationBindComponent
        let meshes = asset.childObjects(of: MDLMesh.self) as! [MDLMesh]
        
        let mesh = meshes.first!
        mesh.addTangentBasis(forTextureCoordinateAttributeNamed: MDLVertexAttributeTextureCoordinate,
                             normalAttributeNamed: MDLVertexAttributeNormal,
                             tangentAttributeNamed: MDLVertexAttributeTangent)
        mesh.addTangentBasis(forTextureCoordinateAttributeNamed: MDLVertexAttributeTextureCoordinate,
                             tangentAttributeNamed: MDLVertexAttributeTangent,
                             bitangentAttributeNamed: MDLVertexAttributeBitangent)
        
        let submesh = (mesh.submeshes!.firstObject! as! MDLSubmesh)
        skeleton = asset.childObjects(of: MDLSkeleton.self).first! as! MDLSkeleton
        animation = animationBinding.jointAnimation as! MDLPackedJointAnimation
        mtkVertexBuffer = mesh.vertexBuffers.first! as! MTKMeshBuffer
        mtkIndexBuffer = submesh.indexBuffer as! MTKMeshBuffer
        geometryType = mtlPrimitiveType(fromMdl: submesh.geometryType)!
        indexType = mtlIndexType(fromMdl: submesh.indexType)!
        indexCount = submesh.indexCount
        
        var prototype = ObjectConstants()
        objectConstantsBuff = device.makeBuffer(bytes: &prototype, length: MemoryLayout<ObjectConstants>.stride, options: .storageModeShared)!
        
        // set color, otherwise it's transparent, as there is no color information loaded from the file
        let ptr = mtkVertexBuffer.buffer.contents().bindMemory(to: VertexData.self, capacity: mesh.vertexCount)
        for i in 0..<mesh.vertexCount {
            ptr[i].color = [0.7, 0.3, 0.0, 1.0];
        }
    }
}

/*
 First 3 vertices:
 
 p: (1.3320212, 0.049512208, 0.03376835)
 n: (0.92391944, 0.38258716, 0)
 ji: 0, 0, 1, 2
 jw: 0.0, 0.0262585, 0.9725228, 0.00121869
  
 p: (1.4128065, -0.14557809, 0.033768304)
 n: (0.92391944, 0.38258716, 0)
 ji: 0, 0, 1, 2
 jw: 0, 0.0025453113, 0.99638903, 0.0010656823
 
 p: (1.4559007, -0.3331712, 0.03376823)
 n: (0.97461444, 0.22388992, 0)
 ji: 0, 1, 2, 0
 jw: 0, 0.9961788, 0.0038212303, 0
 
 */

/*
 The default vertex decriptor for butterfly.usda:
 
 <MDLVertexDescriptor: 0x600003c57600 attributes:(
     "<MDLVertexAttribute: 0x6000026f60c0 name=position format=Float3 bufferIndex=0 offset=0>",
     "<MDLVertexAttribute: 0x6000026f6b40 name=normal format=Float3 bufferIndex=1 offset=0>",
     "<MDLVertexAttribute: 0x6000026f6380 name=textureCoordinate format=Float2 bufferIndex=2 offset=0>",
     "<MDLVertexAttribute: 0x6000026f6140 name=jointIndices format=UShort4 bufferIndex=3 offset=0>",
     "<MDLVertexAttribute: 0x6000026f6100 name=jointWeights format=Float4 bufferIndex=4 offset=0>"
 ) layouts:{
     0 = "<MDLVertexBufferLayout: 0x600003ec0ef0 stride=12>";
     3 = "<MDLVertexBufferLayout: 0x600003ec0fa0 stride=8>";
     2 = "<MDLVertexBufferLayout: 0x600003ec0f50 stride=8>";
     1 = "<MDLVertexBufferLayout: 0x600003ec0f80 stride=12>";
     4 = "<MDLVertexBufferLayout: 0x600003ec0f40 stride=16>";
 }>
 */
