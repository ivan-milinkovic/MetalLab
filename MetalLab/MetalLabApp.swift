import SwiftUI

@main
struct MetalLabApp: App {
    
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    let viewController = ViewController()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewController)
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
