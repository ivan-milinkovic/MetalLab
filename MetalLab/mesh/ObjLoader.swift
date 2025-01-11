import Foundation

typealias VertexIndexType = UInt32 // metal
let sentinelIndex: VertexIndexType = 0xFFFFFFFF // obj file special value

class ObjMesh {
    let vertices: [Float3]
    var uvs: [Float2]
    var normals: [Float3]
    var faces: [ObjFace]
    var materialFile: String?
    
    init(vertices: [Float3], uvs: [Float2], normals: [Float3], faces: [ObjFace], materialFile: String?) {
        self.vertices = vertices
        self.uvs = uvs
        self.normals = normals
        self.faces = faces
        self.materialFile = materialFile
    }
}

struct ObjIndex {
    let vertexIndex, uvIndex, normalIndex: VertexIndexType
}

struct ObjFace {
    let indices: [ObjIndex]
}

// obj uses right hand coordinate system

func loadObj(_ url: URL) -> ObjMesh {
    let str = try! String(contentsOf: url)
    let lines = str.components(separatedBy: .newlines)
    
    var vertices: [Float3]   = []
    var uvs     : [Float2]   = []
    var normals : [Float3]   = []
    var faces   : [ObjFace] = []
    
    var materialFile: String?
    
    for line in lines {
        let comps = line.components(separatedBy: .whitespaces)
        
        switch comps[0] {
            
        case "mtllib":
            materialFile = comps[1]
            
        case "v":
            // v 1.000000 1.000000 -1.000000
            let coords = comps.suffix(from: 1).map { Float($0)! }
            vertices.append(Float3(coords[0], coords[1], coords[2]))
        
        case "vn":
            let coords = comps.suffix(from: 1).map { Float($0)! }
            normals.append(Float3(coords[0], coords[1], coords[2]))
            
        case "vt":
            let uv = comps.suffix(from: 1).map { Float($0)! }
            uvs.append(Float2(uv[0], uv[1]))
            
        case "f":
            // f 5/1/1 3/2/1 1/3/1
            // face vertex/texture/normal
            let faceFTNs = comps.suffix(from: 1)
                .map { vtnStr in
                    let vtn = vtnStr.split(separator: "/").map { VertexIndexType($0)! - 1 } // .obj file indexes start with 1
                    let vertexIndex = vtn[0]
                    let uvIndex     = vtn[1]
                    let normalIndex = vtn[2]
                    let objIndex = ObjIndex(vertexIndex: vertexIndex, uvIndex: uvIndex, normalIndex: normalIndex);
                    return objIndex
            }
            faces.append(ObjFace(indices: faceFTNs))
            
        default:
            break
        }
    }
    
    return ObjMesh(vertices: vertices, uvs: uvs, normals: normals, faces: faces, materialFile: materialFile)
}
