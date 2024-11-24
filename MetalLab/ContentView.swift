import SwiftUI

struct ContentView: View {
    
    @EnvironmentObject var viewController: ViewController
    
    var body: some View {
        MetalView()
            .gesture(DragGesture().onChanged({ dragVal in
                let f: TFloat = 0.00002
                let dx = -f * TFloat(dragVal.velocity.height)
                let dy = -f * TFloat(dragVal.velocity.width)
                //viewController.scene.camera.rotate(dx: dx, dy: dy)
                viewController.scene.sceneObject.positionOrientation.rotate(dx: dx, dy: dy)
            }))
            .task {
                viewController.load()
            }
    }
}
