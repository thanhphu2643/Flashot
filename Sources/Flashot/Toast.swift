import AppKit

/// A short message at the top of the screen under the pointer. Clicking it runs `onClick`.
@MainActor
enum Toast {
    private static var panel: NSPanel?
    private static var hideTask: Task<Void, Never>?

    static func show(_ message: String, onClick: (() -> Void)? = nil) {
        panel?.orderOut(nil)
        let label = NSTextField(labelWithString: message)
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textColor = .white
        label.maximumNumberOfLines = 2
        label.preferredMaxLayoutWidth = 460
        let size = label.fittingSize
        let frame = CGRect(x: 0, y: 0, width: size.width + 32, height: size.height + 18)

        let view = ToastView(frame: frame, onClick: onClick)
        label.frame = CGRect(x: 16, y: 9, width: size.width, height: size.height)
        view.addSubview(label)

        let screen = NSScreen.screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) } ?? NSScreen.main
        let visible = screen?.visibleFrame ?? .zero
        let toast = NSPanel(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        toast.setFrameOrigin(CGPoint(x: visible.midX - frame.width / 2, y: visible.maxY - frame.height - 12))
        toast.level = .statusBar
        toast.isOpaque = false
        toast.backgroundColor = .clear
        toast.hasShadow = true
        toast.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        toast.contentView = view
        toast.orderFrontRegardless()
        panel = toast

        hideTask?.cancel()
        hideTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(onClick == nil ? 1.6 : 3))
            guard !Task.isCancelled else { return }
            panel?.orderOut(nil)
            panel = nil
        }
    }
}

private final class ToastView: NSView {
    private let onClick: (() -> Void)?

    init(frame: CGRect, onClick: (() -> Void)?) {
        self.onClick = onClick
        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = NSColor(white: 0.1, alpha: 0.92).cgColor
        layer?.cornerRadius = frame.height / 2
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is unused") }

    override func mouseDown(with event: NSEvent) {
        onClick?()
        window?.orderOut(nil)
    }
}
