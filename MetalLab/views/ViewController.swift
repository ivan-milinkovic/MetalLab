import Foundation
import MetalKit

@MainActor
class ViewController: NSObject, ObservableObject {
    let scene: MyScene
    let renderer: Renderer
    var mtkView: MTKView!
    let input: Input
    var timeCounter: Double = 0
    var lastFrameTime: Float = 0
    
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
        timeCounter = Time.shared.start
    }
    
    func frameCallback() {
        if !scene.isReady { return }
        scene.update(dt: lastFrameTime, timeCounter: timeCounter)
        renderer.draw(scene: scene)
    }
}


extension ViewController: MTKViewDelegate {
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        if size == .zero { return }
        scene.camera.updateProjection(size: size)
    }
    
    func draw(in view: MTKView) {
        let now = Time.shared.current
        lastFrameTime = Float(now - timeCounter)
        timeCounter = now
        
        frameCallback()
        
        //let updateTime = Float(Time.shared.current - timeCounter)
        //print(String(format: "update time: %.2fms, would be fps: %d", updateTime * 1000, Int(1 / updateTime)))
    }
}
