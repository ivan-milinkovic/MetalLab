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
    
    func keyEvent(char: Character, isActive: Bool) {
        let f: Float = isActive ? 1.0 : 0.0
        switch char {
        case "w": input.forward = f
        case "s": input.back = f
        case "a": input.left = f
        case "d": input.right = f
        case "e": input.up = f
        case "q": input.down = f
        default: break
        }
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
