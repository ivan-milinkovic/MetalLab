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
                        Button("anim") { viewController.scene.selection = viewController.scene.animMesh }
                        Button("node") { viewController.scene.selection = viewController.scene.fileScene }
                    }
                }
                
                Button("Toggle Wireframe") {
                    viewController.renderer.triangleFillMode = (viewController.renderer.triangleFillMode == .fill) ? .lines : .fill
                }
                
                Text("controls: w s a d q e, click-drag")
            }
        }
        .task {
            focused = true
            viewController.load()
        }
        /*
        // If using this code, then comment out input.startMonitoringEvents()
        // This approach has issues: press and hold a key, click-drag with the mouse -> loses focus and misses key events
        .focusable()
        .focused($focused)
        .onKeyPress(characters: CharacterSet.init(charactersIn: "wsadqe"), phases: [.down, .repeat, .up]) { keyPress in
            if keyPress.modifiers.isEmpty == false { return .ignored }
            let isActive = keyPress.phase == .down || keyPress.phase == .repeat
            let isHandled = viewController.input.keyEvent(char: keyPress.key.character, isActive: isActive)
            return isHandled ? .handled : .ignored
        }
        */
    }
}
