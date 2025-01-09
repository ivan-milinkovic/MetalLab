import SwiftUI

struct ContentView: View {
    
    @EnvironmentObject var viewController: ViewController
    
    var body: some View {
        VStack {
            MetalView()
                .gesture(DragGesture().onChanged({ dragVal in
                    let f: Float = 0.000008
                    let dx = f * Float(dragVal.velocity.height)
                    let dy = f * Float(dragVal.velocity.width)
                    viewController.scene.rotateSelection(dx: dx, dy: dy)
                }))
            GroupBox {
                HStack {
                    Text("Select:")
                    Button("camera") { viewController.scene.selection = viewController.scene.camera }
                    Button("monkey") { viewController.scene.selection = viewController.scene.monkey }
                    Button("cube")   { viewController.scene.selection = viewController.scene.normalMapCube }
                }
            }
        }
        .task {
            viewController.load()
        }
    }
}
