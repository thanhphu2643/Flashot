import AppKit
import Carbon.HIToolbox
import Observation

/// A global key combination, stored with Carbon modifier flags.
struct Shortcut: Codable, Equatable {
    var keyCode: Int
    var modifiers: Int
    var key: String

    static let region = Shortcut(keyCode: kVK_ANSI_S, modifiers: optionKey | shiftKey, key: "S")
    static let fullScreen = Shortcut(keyCode: kVK_ANSI_1, modifiers: cmdKey | shiftKey, key: "1")

    init(keyCode: Int, modifiers: Int, key: String) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.key = key
    }

    /// Nil unless ⌘, ⌥ or ⌃ is held: a bare key would fire while typing.
    init?(event: NSEvent) {
        let flags = event.modifierFlags
        var modifiers = 0
        if flags.contains(.control) { modifiers |= controlKey }
        if flags.contains(.option) { modifiers |= optionKey }
        if flags.contains(.shift) { modifiers |= shiftKey }
        if flags.contains(.command) { modifiers |= cmdKey }
        guard modifiers & (cmdKey | optionKey | controlKey) != 0 else { return nil }
        self.init(keyCode: Int(event.keyCode), modifiers: modifiers, key: Shortcut.name(of: event))
    }

    var label: String {
        var s = ""
        if modifiers & controlKey != 0 { s += "⌃" }
        if modifiers & optionKey != 0 { s += "⌥" }
        if modifiers & shiftKey != 0 { s += "⇧" }
        if modifiers & cmdKey != 0 { s += "⌘" }
        return s + key
    }

    var menuModifiers: NSEvent.ModifierFlags {
        var flags: NSEvent.ModifierFlags = []
        if modifiers & controlKey != 0 { flags.insert(.control) }
        if modifiers & optionKey != 0 { flags.insert(.option) }
        if modifiers & shiftKey != 0 { flags.insert(.shift) }
        if modifiers & cmdKey != 0 { flags.insert(.command) }
        return flags
    }

    private static func name(of event: NSEvent) -> String {
        let named: [Int: String] = [
            kVK_Space: "Space", kVK_Return: "↩", kVK_Tab: "⇥", kVK_Delete: "⌫", kVK_ForwardDelete: "⌦",
            kVK_LeftArrow: "←", kVK_RightArrow: "→", kVK_UpArrow: "↑", kVK_DownArrow: "↓",
            kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4", kVK_F5: "F5", kVK_F6: "F6",
            kVK_F7: "F7", kVK_F8: "F8", kVK_F9: "F9", kVK_F10: "F10", kVK_F11: "F11", kVK_F12: "F12",
        ]
        if let name = named[Int(event.keyCode)] { return name }
        // The bare key, so ⇧1 reads "1" and ⌥S reads "S", not "!" and "ß".
        return (event.characters(byApplyingModifiers: []) ?? "?").uppercased()
    }
}

@MainActor
@Observable
final class Settings {
    static let shared = Settings()

    var regionShortcut: Shortcut { didSet { store(regionShortcut, "regionShortcut") } }
    var fullScreenShortcut: Shortcut { didSet { store(fullScreenShortcut, "fullScreenShortcut") } }
    var folder: URL { didSet { defaults.set(folder.path, forKey: "folder"); History.shared.reload() } }
    /// Enter also saves a file, not only copies.
    var autoSave: Bool { didSet { defaults.set(autoSave, forKey: "autoSave") } }
    var showWindowAtLaunch: Bool { didSet { defaults.set(showWindowAtLaunch, forKey: "showWindowAtLaunch") } }

    /// True while the settings screen is recording a shortcut, so the hot keys stay quiet.
    var isRecording = false { didSet { onShortcutsChange?() } }
    /// Shortcuts another app already owns.
    var takenShortcuts: [Shortcut] = []

    @ObservationIgnored var onShortcutsChange: (() -> Void)?
    @ObservationIgnored private let defaults = UserDefaults.standard

    private init() {
        let defaults = UserDefaults.standard
        func load(_ key: String) -> Shortcut? {
            defaults.data(forKey: key).flatMap { try? JSONDecoder().decode(Shortcut.self, from: $0) }
        }
        regionShortcut = load("regionShortcut") ?? .region
        fullScreenShortcut = load("fullScreenShortcut") ?? .fullScreen
        let pictures = FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask)[0]
        folder = defaults.string(forKey: "folder").map { URL(fileURLWithPath: $0) } ?? pictures.appendingPathComponent("Flashot")
        autoSave = defaults.bool(forKey: "autoSave")
        showWindowAtLaunch = defaults.object(forKey: "showWindowAtLaunch") as? Bool ?? true
    }

    private func store(_ shortcut: Shortcut, _ key: String) {
        defaults.set(try? JSONEncoder().encode(shortcut), forKey: key)
        onShortcutsChange?()
    }
}
