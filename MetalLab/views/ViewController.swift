import Foundation
import MetalKit

@MainActor
class ViewController: NSObject, ObservableObject {
    let scene: MyScene
    let renderer: Renderer
    var mtkView: MTKView!
    let input: Input
    var timeCounter: Double = 0
    
    override init() {
        scene = MyScene()
        renderer = Renderer()
        input = Input()
        scene.renderer = renderer
        scene.input = input
        try! renderer.setupDevice()
    }
    
    func load() {
        input.startMonitoringEvents()
        scene.load(device: renderer.device)
        scene.camera.updateProjection(size: mtkView.drawableSize)
    }
    
    func setMtkView(_ mtkView: MTKView) {
        self.mtkView = mtkView
        renderer.setMtkView(mtkView)
        timeCounter = CACurrentMediaTime()
    }
    
    func frameCallback(_ dt: Float) {
        if !scene.isReady { return }
        scene.update(dt: dt, timeCounter: timeCounter)
        renderer.draw(scene: scene)
    }
}


extension ViewController: MTKViewDelegate {
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        if size == .zero { return }
        scene.camera.updateProjection(size: size)
    }
    
    func draw(in view: MTKView) {
        let t = CACurrentMediaTime()
        let dt = t - timeCounter
        timeCounter = t
        
        frameCallback(Float(dt))
        
        //let updateTime = CACurrentMediaTime() - t
        //print(String(format: "frame time: %.2fms, ~fps: %d", updateTime * 1000, Int(1 / updateTime)))
    }
}
