import AppKit
import Carbon.HIToolbox

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private var hotKeys: [HotKey] = []
    private var regionItem: NSMenuItem!
    private var fullScreenItem: NSMenuItem!
    private let settings = Settings.shared

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.mainMenu = mainMenu()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "camera.viewfinder", accessibilityDescription: "Flashot")
        let menu = NSMenu()
        menu.delegate = self
        regionItem = item(menu, "Chụp vùng màn hình", #selector(captureRegion))
        fullScreenItem = item(menu, "Chụp toàn màn hình", #selector(captureFullScreen))
        menu.addItem(.separator())
        item(menu, "Mở Flashot", #selector(openHome))
        item(menu, "Lịch sử ảnh", #selector(openHistory))
        item(menu, "Cài đặt…", #selector(openSettings), key: ",")
        menu.addItem(.separator())
        item(menu, "Thoát Flashot", #selector(NSApplication.terminate(_:)), key: "q", target: NSApp)
        statusItem.menu = menu

        settings.onShortcutsChange = { [weak self] in self?.registerHotKeys() }
        registerHotKeys()

        if settings.showWindowAtLaunch { MainWindow.shared.show() }
    }

    /// Opening the app again (Finder, Spotlight, Dock) brings the window back.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        MainWindow.shared.show()
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    private func registerHotKeys() {
        hotKeys.removeAll() // unregister first, or re-registering the same keys fails
        guard !settings.isRecording else { return }
        var taken: [Shortcut] = []
        for (id, shortcut, fullScreen) in [(UInt32(1), settings.regionShortcut, false), (2, settings.fullScreenShortcut, true)] {
            if let hotKey = HotKey(keyCode: shortcut.keyCode, modifiers: shortcut.modifiers, id: id, action: {
                CaptureSession.start(fullScreen: fullScreen)
            }) {
                hotKeys.append(hotKey)
            } else {
                taken.append(shortcut)
            }
        }
        settings.takenShortcuts = taken
    }

    func menuWillOpen(_ menu: NSMenu) {
        for (item, shortcut) in [(regionItem!, settings.regionShortcut), (fullScreenItem!, settings.fullScreenShortcut)] {
            let single = shortcut.key.count == 1
            item.keyEquivalent = single ? shortcut.key.lowercased() : ""
            item.keyEquivalentModifierMask = single ? shortcut.menuModifiers : []
        }
    }

    @discardableResult
    private func item(_ menu: NSMenu, _ title: String, _ action: Selector, key: String = "", target: AnyObject? = nil) -> NSMenuItem {
        let item = menu.addItem(withTitle: title, action: action, keyEquivalent: key)
        item.target = target ?? self
        return item
    }

    /// Shown while the window is open: app menu, Edit (for text fields) and Window.
    private func mainMenu() -> NSMenu {
        let main = NSMenu()
        let app = NSMenu()
        app.addItem(withTitle: "Giới thiệu Flashot", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        app.addItem(.separator())
        item(app, "Cài đặt…", #selector(openSettings), key: ",")
        app.addItem(.separator())
        app.addItem(withTitle: "Ẩn Flashot", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        app.addItem(withTitle: "Thoát Flashot", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        main.addItem(withTitle: "", action: nil, keyEquivalent: "").submenu = app

        let edit = NSMenu(title: "Sửa")
        edit.addItem(withTitle: "Cắt", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: "Sao chép", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "Dán", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: "Chọn tất cả", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        main.addItem(withTitle: "Sửa", action: nil, keyEquivalent: "").submenu = edit

        let window = NSMenu(title: "Cửa sổ")
        window.addItem(withTitle: "Thu nhỏ", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        window.addItem(withTitle: "Đóng", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        main.addItem(withTitle: "Cửa sổ", action: nil, keyEquivalent: "").submenu = window
        NSApp.windowsMenu = window
        return main
    }

    @objc private func captureRegion() { MainWindow.shared.capture(fullScreen: false) }
    @objc private func captureFullScreen() { MainWindow.shared.capture(fullScreen: true) }
    @objc private func openHome() { MainWindow.shared.show(.home) }
    @objc private func openHistory() { MainWindow.shared.show(.history) }
    @objc private func openSettings() { MainWindow.shared.show(.settings) }
}
