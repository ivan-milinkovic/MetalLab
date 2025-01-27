import Foundation
import Metal
import MetalKit

class MetalMesh {
    
    let vertexBuffer: MTLBuffer
    let vertexCount: Int
    
    let indexBuffer: MTLBuffer?
    let indexCount: Int
      
    init(vertices: [VertexData], indices: [VertexIndexType]? = nil, device: MTLDevice) {
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
    }
    
    static func loadObjFile(_ url: URL, device: MTLDevice) -> MetalMesh {
        let objMesh = loadObj(url)
        let vertexData = nonIndexedVertexDataFromObjMesh(objMesh)
        return MetalMesh(vertices: vertexData, indices: nil, device: device)
    }
    
    static func nonIndexedVertexDataFromObjMesh(_ objMesh: ObjMesh) -> [VertexData] {
        var vertexData: [VertexData] = []
        for face in objMesh.faces {
            
            let p0 = objMesh.vertices[Int(face.indices[0].vertexIndex)]
            let p1 = objMesh.vertices[Int(face.indices[1].vertexIndex)]
            let p2 = objMesh.vertices[Int(face.indices[2].vertexIndex)]
            
            let n0 = objMesh.normals[Int(face.indices[0].normalIndex)]
            let n1 = objMesh.normals[Int(face.indices[1].normalIndex)]
            let n2 = objMesh.normals[Int(face.indices[2].normalIndex)]
            
            let uv0 = objMesh.uvs[Int(face.indices[0].uvIndex)]
            let uv1 = objMesh.uvs[Int(face.indices[1].uvIndex)]
            let uv2 = objMesh.uvs[Int(face.indices[2].uvIndex)]
            
            let (tan0, btan0) = makeTangent(p0: p0, p1: p1, p2: p2, uv0: uv0, uv1: uv1, uv2: uv2, n: n0)
            let (tan1, btan1) = makeTangent(p0: p0, p1: p1, p2: p2, uv0: uv0, uv1: uv1, uv2: uv2, n: n1)
            let (tan2, btan2) = makeTangent(p0: p0, p1: p1, p2: p2, uv0: uv0, uv1: uv1, uv2: uv2, n: n2)
            
            let vdata0 = VertexData(position: p0, normal: n0, color: Float4.one, uv: uv0, tan: tan0, btan: btan0)
            let vdata1 = VertexData(position: p1, normal: n1, color: Float4.one, uv: uv1, tan: tan1, btan: btan1)
            let vdata2 = VertexData(position: p2, normal: n2, color: Float4.one, uv: uv2, tan: tan2, btan: btan2)
            
            vertexData.append(vdata0)
            vertexData.append(vdata1)
            vertexData.append(vdata2)
        }
        return vertexData
    }
    
    static func loadTexture(_ name: String, srgb: Bool = false, _ device: MTLDevice) -> MTLTexture {
        let tl = MTKTextureLoader(device: device)
        let url = Bundle.main.url(forResource: name, withExtension: nil)!
        let tex = try! tl.newTexture(URL: url, options: [.textureUsage: MTLTextureUsage.shaderRead.rawValue,
                                                         .textureStorageMode: MTLStorageMode.private.rawValue,
                                                         .generateMipmaps: true,
                                                         .SRGB : srgb])
        return tex
    }
    
    func setColor(_ color: Float4) {
        for i in 0..<vertexCount {
            let vertexData = vertexBuffer.contents().advanced(by: i * MemoryLayout<VertexData>.stride)
                .bindMemory(to: VertexData.self, capacity: 1)
            vertexData.pointee.color = color;
        }
    }
    
    static func triangle(device: MTLDevice) -> MetalMesh {
        let n:Float3 = [0, 0, -1]
        let triangle: [VertexData] = [
            VertexData(position: [ 0,  1, 0], normal: n, color: [0, 0, 1, 1], uv: [ 0.5,    0], tan: VertexData.xTan, btan: VertexData.yTan), // top
            VertexData(position: [-1, -1, 0], normal: n, color: [0, 1, 0, 1], uv: [ 0.0,  1.0], tan: VertexData.xTan, btan: VertexData.yTan), // bot left
            VertexData(position: [ 1, -1, 0], normal: n, color: [1, 0, 0, 1], uv: [ 1.0,  1.0], tan: VertexData.xTan, btan: VertexData.yTan), // bot right, counter-clockwise
        ]
        return MetalMesh(vertices: triangle, device: device)
    }
    
    static func rectangle(device: MTLDevice) -> MetalMesh {
        let n:Float3 = [0, 0, 1] // -1?
        let tan: Float3 = [1, 0, 0]
        let btan: Float3 = [0, 1, 0]
        let triangle: [VertexData] = [
            VertexData(position: [-1,  1, 0], normal: n, color: .one, uv: [ 0.0,  0.0], tan: tan, btan: btan), // top left
            VertexData(position: [-1, -1, 0], normal: n, color: .one, uv: [ 0.0,  1.0], tan: tan, btan: btan), // bot left
            VertexData(position: [ 1, -1, 0], normal: n, color: .one, uv: [ 1.0,  1.0], tan: tan, btan: btan), // bot right, counter-clockwise
            
            VertexData(position: [-1,  1, 0], normal: n, color: .one, uv: [ 0.0,  0.0], tan: tan, btan: btan), // top left
            VertexData(position: [ 1, -1, 0], normal: n, color: .one, uv: [ 1.0,  1.0], tan: tan, btan: btan), // bot right
            VertexData(position: [ 1,  1, 0], normal: n, color: .one, uv: [ 1.0,  0.0], tan: tan, btan: btan), // top right, counter-clockwise
        ]
        return MetalMesh(vertices: triangle, device: device)
    }
    
    static func rectangle(p1: Float3, p2: Float3, device: MTLDevice) -> MetalMesh {
        let x_min = min(p1.x, p2.x)
        let y_min = min(p1.y, p2.y)
        let z_min = min(p1.z, p2.z)
        let x_max = max(p1.x, p2.x)
        let y_max = max(p1.y, p2.y)
        let z_max = max(p1.z, p2.z)
        
        let v1: Float3 = [x_min, y_max, z_min]
        let v2: Float3 = [x_min, y_min, z_max]
        let n : Float3 = normalize(cross(v1, v2))
        let color = Float4(0.5, 0.5, 0.6, 1)
        let tan: Float3 = [1, 0, 0]
        let btan = normalize(cross(n, tan))
        let triangle: [VertexData] = [
            VertexData(position: [x_min, y_max, z_min], normal: n, color: color, uv: [ 0.0,  0.0], tan: tan, btan: btan), // top left front
            VertexData(position: [x_min, y_min, z_max], normal: n, color: color, uv: [ 0.0,  1.0], tan: tan, btan: btan), // bot left front
            VertexData(position: [x_max, y_min, z_max], normal: n, color: color, uv: [ 1.0,  1.0], tan: tan, btan: btan), // bot right front, counter-clockwise
            
            VertexData(position: [x_min, y_max, z_min], normal: n, color: color, uv: [ 0.0,  0.0], tan: tan, btan: btan), // top left back
            VertexData(position: [x_max, y_min, z_max], normal: n, color: color, uv: [ 1.0,  1.0], tan: tan, btan: btan), // bot right back
            VertexData(position: [x_max, y_max, z_min], normal: n, color: color, uv: [ 1.0,  0.0], tan: tan, btan: btan), // top right back, counter-clockwise
        ]
        return MetalMesh(vertices: triangle, device: device)
        //return MetalMesh(vertices: triangle, texture: loadPlaceholderTexture(device), device: device)
    }
    
    static func grassStrand(_ device: MTLDevice) -> MetalMesh {
        let n = Float3(0,0,1)
        let colBot = Float4(  0, 0.1,  0, 1)
        let colTop = Float4(0.2, 0.4, 0.15, 1)
        let w: Float = 0.1
        let fs: Float = 0.35 // shrink factor
        let vertices: [VertexData] = [
            VertexData(position: [fs*w, 1, 0], normal: n, color: colTop, uv: [ 0.0,  0.0], tan: VertexData.xTan, btan: VertexData.yTan), // top left
            VertexData(position: [   0, 0, 0], normal: n, color: colBot, uv: [ 0.0,  1.0], tan: VertexData.xTan, btan: VertexData.yTan), // bot left
            VertexData(position: [   w, 0, 0], normal: n, color: colBot, uv: [ 1.0,  1.0], tan: VertexData.xTan, btan: VertexData.yTan), // bot right, counter-clockwise
            
            VertexData(position: [    fs*w, 1, 0], normal: n, color: colTop, uv: [ 0.0,  0.0], tan: VertexData.xTan, btan: VertexData.yTan), // top left
            VertexData(position: [       w, 0, 0], normal: n, color: colBot, uv: [ 1.0,  1.0], tan: VertexData.xTan, btan: VertexData.yTan), // bot right
            VertexData(position: [(1-fs)*w, 1, 0], normal: n, color: colTop, uv: [ 1.0,  0.0], tan: VertexData.xTan, btan: VertexData.yTan), // top right, counter-clockwise
        ]
        let metalMesh = MetalMesh(vertices: vertices, device: device)
        return metalMesh
    }
}
