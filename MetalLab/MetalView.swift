import SwiftUI
import MetalKit

struct MetalView: NSViewRepresentable {
    
    @EnvironmentObject var viewController: ViewController
    
    func makeNSView(context: Context) -> MTKView {
        let mtkView = MTKView()
        try! viewController.renderer.setMtkView(mtkView)
        mtkView.delegate = viewController
        return mtkView
    }
    
    func updateNSView(_ nsView: MTKView, context: Context) {
        
    }
}
