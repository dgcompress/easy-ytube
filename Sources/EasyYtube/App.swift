import SwiftUI

@main
struct EasyYtubeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // A single `Window` (not `WindowGroup`) avoids macOS spawning a second
        // window when the Dock icon is clicked after the window was hidden
        // (not closed) by AppDelegate's windowShouldClose override.
        Window("EasyYtube", id: "main") {
            ContentView()
        }
        .windowResizability(.contentSize)
    }
}
