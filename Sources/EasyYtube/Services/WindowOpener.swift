import Foundation

/// Lets the AppDelegate (plain AppKit, no SwiftUI environment) ask the SwiftUI
/// `Window` scene to recreate its window via `openWindow(id:)` if it was ever
/// fully closed rather than just hidden. ContentView captures the action on
/// appear; AppDelegate falls back to it whenever it has no live window reference.
@MainActor
final class WindowOpener {
    static let shared = WindowOpener()
    var openMainWindow: (() -> Void)?
}
