import SwiftUI

struct ContentView: View {
    
    @EnvironmentObject var viewController: ViewController
    @FocusState var focused: Bool
    
    var body: some View {
        VStack {
            MetalView()
                .gesture(DragGesture().onChanged({ dragVal in
                    let f: Float = 0.000008
                    let dx = f * Float(dragVal.velocity.height)
                    let dy = f * Float(dragVal.velocity.width)
                    viewController.scene.rotateSelection(dx: dx, dy: dy)
                }))
            
            HStack(spacing: 8) {
                GroupBox {
                    HStack {
                        Text("Select:")
                        Button("camera") { viewController.scene.selection = viewController.scene.camera }
                        Button("monkey") { viewController.scene.selection = viewController.scene.monkey }
                        Button("cobble")   { viewController.scene.selection = viewController.scene.normalMapPlane }
                    }
                }
                
                Button("Toggle Wireframe") {
                    viewController.renderer.triangleFillMode = (viewController.renderer.triangleFillMode == .fill) ? .lines : .fill
                }
                
                Text("controls: w s a d q e, click-drag")
            }
        }
        .focusable()
        .focused($focused)
        .task {
            focused = true
            viewController.load()
        }
        .onKeyPress(characters: CharacterSet.init(charactersIn: "wsadqe"), phases: [.down, .repeat, .up]) { keyPress in
            let isActive = keyPress.phase == .down || keyPress.phase == .repeat
            viewController.keyEvent(char: keyPress.key.character, isActive: isActive)
            return .handled
        }
    }
}
