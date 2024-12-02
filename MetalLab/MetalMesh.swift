import Foundation
import Metal
import MetalKit

class MetalMesh {
    
    let vertexBuffer: MTLBuffer
    let vertexCount: Int
    
    let indexBuffer: MTLBuffer?
    let indexCount: Int
    
    var texture: MTLTexture?
    
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
    
    static func loadObjFile(_ url: URL, device: MTLDevice) -> MetalMesh {
        let objMesh = loadObj(url)
        let vertexData = nonIndexedVertexDataFromObjMesh(objMesh)
        return MetalMesh(vertices: vertexData, indices: nil, texture: nil, device: device)
    }
    
    static func nonIndexedVertexDataFromObjMesh(_ objMesh: ObjMesh) -> [VertexData] {
        var vertexData: [VertexData] = []
        for face in objMesh.faces {
            for faceFTN in face.indices {
                let vdata = VertexData(position: objMesh.vertices[Int(faceFTN.vertexIndex)],
                                       normal: objMesh.normals[Int(faceFTN.normalIndex)],
                                       color: Float4.one,
                                       uv: objMesh.uvs[Int(faceFTN.uvIndex)])
                vertexData.append(vdata)
            }
        }
        return vertexData
    }
    
    static func loadPlaceholderTexture(_ device: MTLDevice) -> MTLTexture {
        let tl = MTKTextureLoader(device: device)
        let tex = try! tl.newTexture(name: "tex", scaleFactor: 1.0, bundle: .main,
                                     options: [.textureUsage: MTLTextureUsage.shaderRead.rawValue,
                                               .textureStorageMode: MTLStorageMode.private.rawValue])
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
            VertexData(position: [ 0,  1, 0], normal: n, color: [0, 0, 1, 1], uv: [ 0.5,    0]), // top
            VertexData(position: [-1, -1, 0], normal: n, color: [0, 1, 0, 1], uv: [ 0.0,  1.0]), // bot left
            VertexData(position: [ 1, -1, 0], normal: n, color: [1, 0, 0, 1], uv: [ 1.0,  1.0]), // bot right, counter-clockwise
        ]
        return MetalMesh(vertices: triangle, texture: nil, device: device)
    }
    
    static func rectangle(device: MTLDevice) -> MetalMesh {
        let n:Float3 = [0, 0, -1]
        let triangle: [VertexData] = [
            VertexData(position: [-1,  1, 0], normal: n, color: .one, uv: [ 0.0,  0.0]), // top left
            VertexData(position: [-1, -1, 0], normal: n, color: .one, uv: [ 0.0,  1.0]), // bot left
            VertexData(position: [ 1, -1, 0], normal: n, color: .one, uv: [ 1.0,  1.0]), // bot right, counter-clockwise
            
            VertexData(position: [-1,  1, 0], normal: n, color: .one, uv: [ 0.0,  0.0]), // top left
            VertexData(position: [ 1, -1, 0], normal: n, color: .one, uv: [ 1.0,  1.0]), // bot right
            VertexData(position: [ 1,  1, 0], normal: n, color: .one, uv: [ 1.0,  0.0]), // top right, counter-clockwise
        ]
        let tex = loadPlaceholderTexture(device)
        return MetalMesh(vertices: triangle, texture: tex, device: device)
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
        
        let triangle: [VertexData] = [
            VertexData(position: [x_min, y_max, z_min], normal: n, color: color, uv: [ 0.0,  0.0]), // top left front
            VertexData(position: [x_min, y_min, z_max], normal: n, color: color, uv: [ 0.0,  1.0]), // bot left front
            VertexData(position: [x_max, y_min, z_max], normal: n, color: color, uv: [ 1.0,  1.0]), // bot right front, counter-clockwise
            
            VertexData(position: [x_min, y_max, z_min], normal: n, color: color, uv: [ 0.0,  0.0]), // top left back
            VertexData(position: [x_max, y_min, z_max], normal: n, color: color, uv: [ 1.0,  1.0]), // bot right back
            VertexData(position: [x_max, y_max, z_min], normal: n, color: color, uv: [ 1.0,  0.0]), // top right back, counter-clockwise
        ]
        return MetalMesh(vertices: triangle, texture: nil, device: device)
        //return MetalMesh(vertices: triangle, texture: loadPlaceholderTexture(device), device: device)
    }
    
    static func grassStrand(_ device: MTLDevice) -> MetalMesh {
        let n = Float3(0,0,1)
        let colBot = Float4(  0, 0.25,  0, 1)
        let colTop = Float4(0.6, 0.8, 0.4, 1)
        let w: Float = 0.1
        let fs: Float = 0.25 // shrink factor
        let vertices: [VertexData] = [
            VertexData(position: [fs*w, 1, 0], normal: n, color: colTop, uv: [ 0.0,  0.0]), // top left
            VertexData(position: [   0, 0, 0], normal: n, color: colBot, uv: [ 0.0,  1.0]), // bot left
            VertexData(position: [   w, 0, 0], normal: n, color: colBot, uv: [ 1.0,  1.0]), // bot right, counter-clockwise
            
            VertexData(position: [    fs*w, 1, 0], normal: n, color: colTop, uv: [ 0.0,  0.0]), // top left
            VertexData(position: [       w, 0, 0], normal: n, color: colBot, uv: [ 1.0,  1.0]), // bot right
            VertexData(position: [(1-fs)*w, 1, 0], normal: n, color: colTop, uv: [ 1.0,  0.0]), // top right, counter-clockwise
        ]
        let metalMesh = MetalMesh(vertices: vertices, texture: nil, device: device)
        return metalMesh
    }
}
