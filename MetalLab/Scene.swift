import Foundation
import Metal
import simd

class MyScene {
    
    let camera = Camera()
    var triangleMesh: MyMesh!
    
    func load(device: MTLDevice) {
        let triangle: [VertexData] = [
            VertexData(position: [ 0,  1, -2], normal: [0, 0, -1], color: [0, 0, 1, 1], uv: [ 0.5,    0]), // top
            VertexData(position: [-1, -1, -2], normal: [0, 0, -1], color: [0, 1, 0, 1], uv: [-1.0,  1.0]), // bot left
            VertexData(position: [ 1, -1, -2], normal: [0, 0, -1], color: [1, 0, 0, 1], uv: [ 1.0,  1.0]), // bot right, counter-clockwise
        ]
        triangleMesh = MyMesh(vertices: triangle, device: device)
    }
}
