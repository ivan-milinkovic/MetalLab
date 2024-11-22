import Foundation
import Metal
import MetalKit

typealias VertexIndexType = UInt32
let sentinelIndex: VertexIndexType = 0xFFFFFFFF

class MyMesh {
    let vertexBuffer: MTLBuffer
    let vertexCount: Int
    
    let indexBuffer: MTLBuffer?
    let indexCount: Int
    
    let texture: MTLTexture?
    
    init(vertices: [VertexData], indices: [VertexIndexType]? = nil, texture: MTLTexture?, device: MTLDevice) {
        var vs = vertices
        let byteLength = MemoryLayout<VertexData>.stride * vertices.count
        vertexBuffer = device.makeBuffer(bytes: &vs, length: byteLength, options: .storageModeShared)!
        vertexCount = vertices.count
        
        if var ind = indices {
            let indByteLen = MemoryLayout<VertexIndexType>.stride * ind.count
            self.indexBuffer = device.makeBuffer(bytes: &ind, length: indByteLen, options: .storageModeShared)
            self.indexCount = ind.count
        } else {
            self.indexBuffer = nil
            self.indexCount = 0
        }
        self.texture = texture
    }
    
    static func triangle(device: MTLDevice) -> MyMesh {
        let n:Float3 = [0, 0, -1]
        let triangle: [VertexData] = [
            VertexData(position: [ 0,  1, -2], normal: n, color: [0, 0, 1, 1], uv: [ 0.5,    0]), // top
            VertexData(position: [-1, -1, -2], normal: n, color: [0, 1, 0, 1], uv: [ 0.0,  1.0]), // bot left
            VertexData(position: [ 1, -1, -2], normal: n, color: [1, 0, 0, 1], uv: [ 1.0,  1.0]), // bot right, counter-clockwise
        ]
        return MyMesh(vertices: triangle, texture: nil, device: device)
    }
    
    static func rectangle(device: MTLDevice) -> MyMesh {
        let n:Float3 = [0, 0, -1]
        let triangle: [VertexData] = [
            VertexData(position: [-1,  1, -2], normal: n, color: .one, uv: [ 0.0,  0.0]), // top left
            VertexData(position: [-1, -1, -2], normal: n, color: .one, uv: [ 0.0,  1.0]), // bot left
            VertexData(position: [ 1, -1, -2], normal: n, color: .one, uv: [ 1.0,  1.0]), // bot right, counter-clockwise
            
            VertexData(position: [-1,  1, -2], normal: n, color: .one, uv: [ 0.0,  0.0]), // top left
            VertexData(position: [ 1, -1, -2], normal: n, color: .one, uv: [ 1.0,  1.0]), // bot right
            VertexData(position: [ 1,  1, -2], normal: n, color: .one, uv: [ 1.0,  0.0]), // top right, counter-clockwise
        ]
        let tex = loadPlaceholderTexture(device)
        return MyMesh(vertices: triangle, texture: tex, device: device)
    }
    
    static func monkey(device: MTLDevice) -> MyMesh {
        let url = Bundle.main.url(forResource: "monkey", withExtension: "obj")!
        let ramMesh = loadObj(url)
        return MyMesh(vertices: ramMesh.vertices, indices: nil, texture: nil, device: device)
    }
    
    static func loadPlaceholderTexture(_ device: MTLDevice) -> MTLTexture {
        let tl = MTKTextureLoader(device: device)
        let tex = try! tl.newTexture(name: "tex", scaleFactor: 1.0, bundle: .main,
                                     options: [.textureUsage: MTLTextureUsage.shaderRead.rawValue, .textureStorageMode: MTLStorageMode.private.rawValue])
        return tex
    }
}


struct VertexData {
    let position: Float3
    let normal: Float3
    let color: Float4
    let uv: Float2
    
    
    @MainActor
    static let vertexDescriptor: MTLVertexDescriptor = {
        
        let positionSize = MemoryLayout<Float3>.size
        let normalSize = MemoryLayout<Float3>.size
        let colorSize = MemoryLayout<Float4>.size
        
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
        
        vertexDesc.layouts[0].stride = MemoryLayout<VertexData>.stride
        
        return vertexDesc
    }()
}
