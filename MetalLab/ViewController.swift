import Foundation
import MetalKit

@MainActor
class ViewController: NSObject, ObservableObject {
    let scene: MyScene
    let renderer: Renderer
    
    override init() {
        scene = MyScene()
        renderer = Renderer()
        try! renderer.setup()
        renderer.camera = scene.camera
    }
    
    func load() {
        scene.load(device: renderer.device)
        renderer.mesh = scene.mesh
    }
}

extension ViewController: MTKViewDelegate {
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        renderer.updateProjection()
    }
    
    func draw(in view: MTKView) {
        renderer.update()
        renderer.draw()
    }
}
