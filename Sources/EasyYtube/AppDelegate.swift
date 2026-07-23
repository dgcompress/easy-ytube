import AppKit
import SwiftUI

/// Keeps EasyYtube running in the background with a menu bar icon, mirroring
/// DG Compress: closing the window just hides it instead of quitting the app.
/// Left-click on the menu bar icon shows a quick-add popover (paste a link
/// without opening the full window); right-click shows the classic menu.
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private weak var mainWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        setupStatusItem()
        setupPopover()

        DispatchQueue.main.async { [weak self] in
            guard let window = NSApp.windows.first else { return }
            window.delegate = self
            self?.mainWindow = window
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showMainWindow()
        return true
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        sender.orderOut(nil)
        return false
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
            let image = NSImage(systemSymbolName: "waveform", accessibilityDescription: "EasyYtube")?
                .withSymbolConfiguration(config)
            image?.isTemplate = true
            button.image = image
            button.target = self
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        statusItem = item
    }

    private func setupPopover() {
        let popover = NSPopover()
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: QuickAddView(
                onOpenMainWindow: { [weak self] in
                    self?.popover?.performClose(nil)
                    self?.showMainWindow()
                },
                onQuit: { [weak self] in
                    self?.quitApp()
                }
            )
        )
        self.popover = popover
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        if NSApp.currentEvent?.type == .rightMouseUp {
            showMenu()
        } else {
            togglePopover()
        }
    }

    private func togglePopover() {
        guard let button = statusItem?.button, let popover else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            NSApp.activate(ignoringOtherApps: true)
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    private func showMenu() {
        guard let button = statusItem?.button else { return }

        let menu = NSMenu()

        let openItem = NSMenuItem(title: "Apri EasyYtube", action: #selector(showMainWindowAction), keyEquivalent: "")
        openItem.target = self
        menu.addItem(openItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Esci", action: #selector(quitAppAction), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height + 4), in: button)
    }

    @objc private func showMainWindowAction() {
        showMainWindow()
    }

    @objc private func quitAppAction() {
        quitApp()
    }

    private func showMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        mainWindow?.makeKeyAndOrderFront(nil)
    }

    private func quitApp() {
        NSApp.terminate(nil)
    }
}
