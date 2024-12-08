import Metal

class Pool {
    var metalMeshes: [String: MetalMesh] = [:]
    var positions: [Int: [Transform]] = [:] // object id -> instances (positions)
    
    func loadMesh(_ name: String, device: MTLDevice) -> MetalMesh {
        if let metalMesh = metalMeshes[name] {
            return metalMesh
        }
        let url = Bundle.main.url(forResource: name, withExtension: "obj")!
        let metalMesh = MetalMesh.loadObjFile(url, device: device)
        metalMeshes[name] = metalMesh
        return metalMesh
    }
}
