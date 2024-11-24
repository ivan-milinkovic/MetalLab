
class MeshObject {
    var positionOrientation: PositionOrientation = .init()
    let metalMesh: MetalMesh
    init(metalMesh: MetalMesh) {
        self.metalMesh = metalMesh
    }
}
