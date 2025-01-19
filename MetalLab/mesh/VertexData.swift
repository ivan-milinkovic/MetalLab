import simd
import Metal
import MetalKit

struct VertexData {
    let position: Float3
    let normal: Float3
    var color: Float4
    let uv: Float2
    let tan: Float3
    let btan: Float3
    let ji: simd_ushort4 = .zero
    let jw: Float4 = .zero
    
    static let xTan: Float3 = [1, 0, 0]
    static let yTan: Float3 = [0, 1, 0]
    
    @MainActor
    static let vertexDescriptor: MTLVertexDescriptor = {
        
        let vertexDesc = MTLVertexDescriptor()
        
        vertexDesc.attributes[0].format = .float3;
        vertexDesc.attributes[0].offset = MemoryLayout.offset(of: \VertexData.position)!
        
        vertexDesc.attributes[1].format = .float3;
        vertexDesc.attributes[1].offset = MemoryLayout.offset(of: \VertexData.normal)!
        
        vertexDesc.attributes[2].format = .float4;
        vertexDesc.attributes[2].offset = MemoryLayout.offset(of: \VertexData.color)!
        
        vertexDesc.attributes[3].format = .float2;
        vertexDesc.attributes[3].offset = MemoryLayout.offset(of: \VertexData.uv)!
        
        vertexDesc.attributes[4].format = .float3;
        vertexDesc.attributes[4].offset = MemoryLayout.offset(of: \VertexData.tan)!
        
        vertexDesc.attributes[5].format = .float3;
        vertexDesc.attributes[5].offset = MemoryLayout.offset(of: \VertexData.btan)!
        
        vertexDesc.attributes[6].format = .ushort4
        vertexDesc.attributes[6].offset = MemoryLayout.offset(of: \VertexData.ji)!
        
        vertexDesc.attributes[7].format = .float4
        vertexDesc.attributes[7].offset = MemoryLayout.offset(of: \VertexData.jw)!
        
        for i in 0...7 { vertexDesc.attributes[i].bufferIndex = 0 }
        
        vertexDesc.layouts[0].stride = MemoryLayout<VertexData>.stride
        
        return vertexDesc
    }()
    
    @MainActor
    static let tessellationVertexDescriptor: MTLVertexDescriptor = {
        let vd = vertexDescriptor.copy() as! MTLVertexDescriptor
        vd.layouts[0].stepRate = 1
        vd.layouts[0].stepFunction = .perPatchControlPoint
        return vd
    }()
    
    static func makeModelioVertexDescriptor() -> MDLVertexDescriptor {
        //return MTKModelIOVertexDescriptorFromMetal(vertexDescriptor) // causes a crash later in MDLMesh.addTangentBasis
        
        let vertexDescriptor = MDLVertexDescriptor()
        var index: Int = 0
        
        vertexDescriptor.vertexAttributes[index].name = MDLVertexAttributePosition
        vertexDescriptor.vertexAttributes[index].format = .float4
        vertexDescriptor.vertexAttributes[index].offset = MemoryLayout.offset(of: \VertexData.position)!
        index += 1
        
        vertexDescriptor.vertexAttributes[index].name = MDLVertexAttributeNormal
        vertexDescriptor.vertexAttributes[index].format = .float4
        vertexDescriptor.vertexAttributes[index].offset = MemoryLayout.offset(of: \VertexData.normal)!
        index += 1
        
        vertexDescriptor.vertexAttributes[index].name = MDLVertexAttributeColor
        vertexDescriptor.vertexAttributes[index].format = .float4
        vertexDescriptor.vertexAttributes[index].offset = MemoryLayout.offset(of: \VertexData.color)!
        index += 1
        
        vertexDescriptor.vertexAttributes[index].name = MDLVertexAttributeTextureCoordinate
        vertexDescriptor.vertexAttributes[index].format = .float2
        vertexDescriptor.vertexAttributes[index].offset = MemoryLayout.offset(of: \VertexData.uv)!
        index += 1
        
        vertexDescriptor.vertexAttributes[index].name = MDLVertexAttributeTangent
        vertexDescriptor.vertexAttributes[index].format = .float3
        vertexDescriptor.vertexAttributes[index].offset = MemoryLayout.offset(of: \VertexData.tan)!
        index += 1
        
        vertexDescriptor.vertexAttributes[index].name = MDLVertexAttributeBitangent
        vertexDescriptor.vertexAttributes[index].format = .float3
        vertexDescriptor.vertexAttributes[index].offset = MemoryLayout.offset(of: \VertexData.btan)!
        index += 1
        
        vertexDescriptor.vertexAttributes[index].name = MDLVertexAttributeJointIndices
        vertexDescriptor.vertexAttributes[index].format = .uShort4
        vertexDescriptor.vertexAttributes[index].offset = MemoryLayout.offset(of: \VertexData.ji)!
        index += 1
        
        vertexDescriptor.vertexAttributes[index].name = MDLVertexAttributeJointWeights
        vertexDescriptor.vertexAttributes[index].format = .float4
        vertexDescriptor.vertexAttributes[index].offset = MemoryLayout.offset(of: \VertexData.jw)!
        index += 1
        
        for i in 0..<index { vertexDescriptor.vertexAttributes[i].bufferIndex = 0 }
        
        vertexDescriptor.bufferLayouts[0].stride = MemoryLayout<VertexData>.stride
        
        //print("buffer stride: ", MemoryLayout<VertexData>.stride)
        return vertexDescriptor
    }

}
