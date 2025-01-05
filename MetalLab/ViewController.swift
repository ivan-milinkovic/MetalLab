import Foundation
import MetalKit

@MainActor
class ViewController: NSObject, ObservableObject {
    let scene: MyScene
    let renderer: Renderer
    var mtkView: MTKView!
    var timeCounter: Double = 0
    
    @Published var isNormalMappingOn = false {
        didSet {
            scene.updateNormalMapping()
        }
    }
    
    override init() {
        scene = MyScene()
        renderer = Renderer()
        scene.renderer = renderer
        try! renderer.setupDevice()
    }
    
    func load() {
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
        scene.updateShear(timeCounter: timeCounter, wind: scene.wind)
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
