import Foundation

class RamMesh {
    let vertices: [VertexData]
    let indices: [VertexIndexType]?
    let materialFile: String?
    init(vertices: [VertexData], indices: [VertexIndexType]?, materialFile: String?) {
        self.vertices = vertices
        self.indices = indices
        self.materialFile = materialFile
    }
}

private struct ObjIndex {
    let vertexIndex, uvIndex, normalIndex: VertexIndexType
}

private struct ObjFace {
    let indices: [ObjIndex]
}

// obj uses right hand coordinate system

func loadObj(_ url: URL) -> RamMesh {
    let str = try! String(contentsOf: url)
    let lines = str.components(separatedBy: .newlines)
    
    var vertices: [Float3]   = []
    var uvs     : [Float2]   = []
    var normals : [Float3]   = []
    var facesFTNs: [ObjIndex] = []
//    var faces: [ObjFace] = []
    
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
            comps.suffix(from: 1)
                //.reversed()
                .forEach { vtnStr in
                    let vtn = vtnStr.split(separator: "/").map { VertexIndexType($0)! - 1 } // .obj file indexes start with 1
                    let vertexIndex = vtn[0]
                    let uvIndex     = vtn[1]
                    let normalIndex = vtn[2]
                    let objIndex = ObjIndex(vertexIndex: vertexIndex, uvIndex: uvIndex, normalIndex: normalIndex);
                    facesFTNs.append(objIndex)
            }
            // facesFTNs.append(ObjIndex(vertexIndex: sentinelIndex, uvIndex: sentinelIndex, normalIndex: sentinelIndex))
            
        default:
            break
        }
    }
    
    var vertexData: [VertexData] = []
    var indices: [VertexIndexType] = []
    // var usedIndexSet: Set<VertexIndexType> = [] // if using indexing instead of duplicating vertices
    for faceFTN in facesFTNs {
        if faceFTN.vertexIndex == sentinelIndex {
            indices.append(sentinelIndex)
            continue
        }
        // if usedIndexSet.contains(faceFTN.vertexIndex) {
        //     indices.append(faceFTN.vertexIndex)
        // }
        // this will create duplicate vertices, ignoring indexing
        let vdata = VertexData(position: vertices[Int(faceFTN.vertexIndex)],
                               normal: normals[Int(faceFTN.normalIndex)],
                               color: Float4.ones, //Float4.randomOpaqueColor,
                               uv: uvs[Int(faceFTN.uvIndex)])
        vertexData.append(vdata)
        indices.append(faceFTN.vertexIndex)
    }
    
    let mesh = RamMesh(vertices: vertexData, indices: nil, materialFile: materialFile)
    
    return mesh
}
