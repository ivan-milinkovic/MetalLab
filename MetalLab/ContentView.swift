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
                    if NSEvent.modifierFlags.contains(.option) {
                        viewController.scene.camera.position.rotate2(dx: dx, dy: dy)
                    } else {
                        viewController.scene.selection.transform.rotate2(dx: dx, dy: dy)
                    }
                }))

            Toggle(isOn: $viewController.isNormalMappingOn) {
                Text("Normal Mapping")
            }
            .toggleStyle(.checkbox)
            .padding(.bottom, 8)
        }
        .task {
            viewController.load()
        }
    }
}
