import SwiftUI

struct ContentView: View {
    
    @EnvironmentObject var viewController: ViewController
    
    var body: some View {
        MetalView()
            .gesture(DragGesture().onChanged({ dragVal in
                let f: Float = 0.000008
                let dx = f * Float(dragVal.velocity.height)
                let dy = f * Float(dragVal.velocity.width)
                //viewController.scene.camera.position.rotate(dx: dx, dy: dy)
                viewController.scene.monkey.position.rotate(dx: dx, dy: dy)
            }))
            .task {
                viewController.load()
            }
    }
}
