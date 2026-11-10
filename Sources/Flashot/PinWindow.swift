import AppKit

/// A screenshot kept floating above other windows. Drag to move, scroll to zoom,
/// double-click or Esc to close, right-click for more.
@MainActor
final class PinWindow: NSPanel {
    private static var open: [PinWindow] = []
    private let image: CGImage
    private let scale: CGFloat
    private let aspect: CGFloat

    static func show(_ image: CGImage, scale: CGFloat, frame: CGRect) {
        let pin = PinWindow(image: image, scale: scale, frame: frame)
        open.append(pin)
        pin.orderFrontRegardless()
        pin.makeKey()
    }

    private init(image: CGImage, scale: CGFloat, frame: CGRect) {
        self.image = image
        self.scale = scale
        aspect = frame.width / max(frame.height, 1)
        super.init(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        level = .floating
        hasShadow = true
        isMovableByWindowBackground = true
        isReleasedWhenClosed = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        let view = NSImageView(image: NSImage(cgImage: image, size: frame.size))
        view.imageScaling = .scaleAxesIndependently
        view.wantsLayer = true
        view.layer?.borderColor = NSColor.controlAccentColor.withAlphaComponent(0.6).cgColor
        view.layer?.borderWidth = 1
        contentView = view
        let menu = NSMenu()
        menu.addItem(withTitle: "Sao chép", action: #selector(copyImage), keyEquivalent: "c").target = self
        menu.addItem(withTitle: "Lưu", action: #selector(saveImage), keyEquivalent: "s").target = self
        menu.addItem(withTitle: "Kích thước gốc", action: #selector(resetSize), keyEquivalent: "0").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Đóng", action: #selector(closePin), keyEquivalent: "w").target = self
        view.menu = menu
    }

    override var canBecomeKey: Bool { true }

    override func sendEvent(_ event: NSEvent) {
        // The image view would swallow these; handle them for the whole window.
        if event.type == .leftMouseDown, event.clickCount == 2 {
            closePin()
        } else if event.type == .scrollWheel {
            zoom(by: 1 + event.scrollingDeltaY * (event.hasPreciseScrollingDeltas ? 0.005 : 0.05))
        } else {
            super.sendEvent(event)
        }
    }

    override func keyDown(with event: NSEvent) {
        let command = event.modifierFlags.contains(.command)
        switch (event.keyCode, command, event.charactersIgnoringModifiers ?? "") {
        case (53, _, _), (_, true, "w"): closePin()
        case (_, true, "c"): copyImage()
        case (_, true, "s"): saveImage()
        case (_, true, "0"): resetSize()
        default: super.keyDown(with: event)
        }
    }

    private func zoom(by factor: CGFloat) {
        let old = frame
        let width = min(max(40, old.width * factor), 8000)
        let size = CGSize(width: width, height: width / aspect)
        // Grow around the center.
        setFrame(CGRect(x: old.midX - size.width / 2, y: old.midY - size.height / 2, width: size.width, height: size.height), display: true)
    }

    @objc private func resetSize() {
        let size = CGSize(width: CGFloat(image.width) / scale, height: CGFloat(image.height) / scale)
        setFrame(CGRect(x: frame.midX - size.width / 2, y: frame.midY - size.height / 2, width: size.width, height: size.height), display: true)
    }

    @objc private func copyImage() { Output.copy(image, scale: scale) }
    @objc private func saveImage() { Output.save(image, scale: scale) }

    @objc private func closePin() {
        orderOut(nil)
        PinWindow.open.removeAll { $0 === self }
    }
}
