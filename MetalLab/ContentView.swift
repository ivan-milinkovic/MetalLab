import SwiftUI

struct ContentView: View {
    
    @EnvironmentObject var viewController: ViewController
    
    var body: some View {
        MetalView()
            .gesture(DragGesture().onChanged({ dragVal in
                let f: TFloat = 0.00002
                viewController.scene.camera.rotate(dx: -f * TFloat(dragVal.velocity.height),
                                                   dy: -f * TFloat(dragVal.velocity.width))
                viewController.renderer.updateViewMatrix()
            }))
            .task {
                viewController.load()
            }
    }
}
