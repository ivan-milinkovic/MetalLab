import Foundation
import MetalKit

@MainActor
class ViewController: NSObject, ObservableObject {
    let scene: MyScene
    let renderer: Renderer
    var mtkView: MTKView!
    
    override init() {
        scene = MyScene()
        renderer = Renderer()
        try! renderer.setupDevice()
    }
    
    func load() {
        scene.load(device: renderer.device)
        
        scene.camera.updateProjection(size: mtkView.drawableSize)
    }
    
    func setMtkView(_ mtkView: MTKView) {
        self.mtkView = mtkView
        renderer.setMtkView(mtkView)
    }
    
    func draw() {
        scene.grass.updateShear()
        renderer.draw(scene: scene)
    }
}


extension ViewController: MTKViewDelegate {
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        if size == .zero { return }
        scene.camera.updateProjection(size: size)
    }
    
    func draw(in view: MTKView) {
        //let d0 = Date()
        
        draw()
        
        //let dt = Date().timeIntervalSince(d0)
        //print(String(format: "render time: %.2fms, ~fps: %d", dt * 1000, Int(1 / dt)))
    }
}
