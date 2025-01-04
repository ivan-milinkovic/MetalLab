import Metal

struct VertexData {
    let position: Float3
    let normal: Float3
    var color: Float4
    let uv: Float2
    let tan: Float3
    let btan: Float3
    
    static let xTan: Float3 = [1, 0, 0]
    static let yTan: Float3 = [0, 1, 0]
    
    @MainActor
    static let vertexDescriptor: MTLVertexDescriptor = {
        
        let positionSize = MemoryLayout<Float3>.size
        let normalSize = MemoryLayout<Float3>.size
        let colorSize = MemoryLayout<Float4>.size
        let uvSize = MemoryLayout<Float2>.size
        let tanSize = MemoryLayout<Float3>.size
        
        let vertexDesc = MTLVertexDescriptor()
        
        // position
        vertexDesc.attributes[0].format = .float3;
        vertexDesc.attributes[0].offset = 0;
        vertexDesc.attributes[0].bufferIndex = 0;
        
        // normal
        vertexDesc.attributes[1].format = .float3;
        vertexDesc.attributes[1].offset = positionSize;
        vertexDesc.attributes[1].bufferIndex = 0;
        
        // color
        vertexDesc.attributes[2].format = .float4;
        vertexDesc.attributes[2].offset = positionSize + normalSize;
        vertexDesc.attributes[2].bufferIndex = 0;
        
        // uv
        vertexDesc.attributes[3].format = .float4;
        vertexDesc.attributes[3].offset = positionSize + normalSize + colorSize;
        vertexDesc.attributes[3].bufferIndex = 0;
        
        // tangent
        vertexDesc.attributes[4].format = .float4;
        vertexDesc.attributes[4].offset = positionSize + normalSize + colorSize + uvSize;
        vertexDesc.attributes[4].bufferIndex = 0;
        
        // bitangent
        vertexDesc.attributes[5].format = .float4;
        vertexDesc.attributes[5].offset = positionSize + normalSize + colorSize + uvSize + tanSize;
        vertexDesc.attributes[5].bufferIndex = 0;
        
        vertexDesc.layouts[0].stride = MemoryLayout<VertexData>.stride
        
        return vertexDesc
    }()
}
