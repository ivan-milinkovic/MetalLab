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
        renderer.camera = scene.camera
    }
    
    func load() {
        scene.load(device: renderer.device)
        renderer.mesh = scene.mesh
        
        scene.camera.updateProjection(size: mtkView.drawableSize)
        scene.camera.updateViewMatrix()
    }
    
    func setMtkView(_ mtkView: MTKView) throws(MyError) {
        self.mtkView = mtkView
        try renderer.setMtkView(mtkView)
    }
}

extension ViewController: MTKViewDelegate {
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        scene.camera.updateProjection(size: mtkView.drawableSize)
    }
    
    func draw(in view: MTKView) {
        //let d0 = Date()
        
        renderer.draw()
        
        //let dt = Date().timeIntervalSince(d0)
        //print(String(format: "render time: %.2fms, ~fps: %d", dt * 1000, Int(1 / dt)))
    }
}
