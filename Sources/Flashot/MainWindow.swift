import AppKit
import SwiftUI

enum Tab: Hashable { case home, history, settings }

/// The app's window. While it is open Flashot shows in the Dock like a normal app.
@MainActor
final class MainWindow: NSObject, NSWindowDelegate {
    static let shared = MainWindow()
    let navigation = Navigation()
    private var window: NSWindow?

    func show(_ tab: Tab? = nil) {
        if let tab { navigation.tab = tab }
        let window = window ?? make()
        NSApp.setActivationPolicy(.regular)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }

    /// Captures without this window in the picture, then brings it back.
    func capture(fullScreen: Bool) {
        guard let window, window.isVisible else {
            CaptureSession.start(fullScreen: fullScreen)
            return
        }
        window.orderOut(nil)
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(250)) // let the window server redraw
            CaptureSession.start(fullScreen: fullScreen) { window.makeKeyAndOrderFront(nil) }
        }
    }

    private func make() -> NSWindow {
        let window = NSWindow(
            contentRect: CGRect(x: 0, y: 0, width: 860, height: 580),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered, defer: false
        )
        window.title = "Flashot"
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.minSize = CGSize(width: 720, height: 480)
        window.contentView = NSHostingView(rootView: MainView(navigation: navigation))
        window.delegate = self
        window.center()
        window.setFrameAutosaveName("MainWindow")
        self.window = window
        return window
    }

    func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}

@MainActor
@Observable
final class Navigation {
    var tab: Tab? = .home
}
