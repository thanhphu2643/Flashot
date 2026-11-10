import AppKit

/// One capture: freezes every screen, lets the user pick and mark up a region, then hands
/// the result on. Lives from the hot key until copy, save, pin or cancel.
@MainActor
final class CaptureSession {
    private(set) static var current: CaptureSession?

    private var panels: [NSPanel] = []
    /// The screen the user is selecting on; the others stop taking clicks.
    var activeView: CaptureView?
    private var onEnd: (() -> Void)?

    /// `onEnd` runs once the capture is over, however it ends.
    static func start(fullScreen: Bool = false, onEnd: (() -> Void)? = nil) {
        guard current == nil else { return }
        guard ScreenCapture.ensureAccess() else {
            Toast.show("Cần cấp quyền Ghi màn hình cho Flashot trong Cài đặt hệ thống → Quyền riêng tư & Bảo mật")
            onEnd?()
            return
        }
        let session = CaptureSession()
        session.onEnd = onEnd
        current = session
        let windows = ScreenCapture.windowFrames()
        Task { @MainActor in
            do {
                let shots = try await ScreenCapture.captureAll()
                session.present(shots, windows: windows, fullScreen: fullScreen)
            } catch {
                session.close()
                Toast.show("Không chụp được màn hình: \(error.localizedDescription)")
            }
        }
    }

    private func present(_ shots: [(NSScreen, CGImage)], windows: [CGRect], fullScreen: Bool) {
        let primaryHeight = NSScreen.screens.first?.frame.maxY ?? 0
        let mouse = NSEvent.mouseLocation
        for (screen, image) in shots {
            guard let shot = Shot(image, scale: CGFloat(image.width) / screen.frame.width) else { continue }
            let frame = screen.frame
            let local = windows.compactMap { w -> CGRect? in
                let r = w.offsetBy(dx: -frame.minX, dy: -(primaryHeight - frame.maxY))
                    .intersection(CGRect(origin: .zero, size: frame.size))
                return r.isEmpty ? nil : r
            }
            let panel = OverlayPanel(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            panel.setFrame(frame, display: false)
            panel.level = .screenSaver
            panel.isOpaque = true
            panel.hasShadow = false
            panel.isReleasedWhenClosed = false
            panel.acceptsMouseMovedEvents = true
            panel.animationBehavior = .none
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            let view = CaptureView(session: self, shot: shot, windowFrames: local)
            panel.contentView = view
            panel.orderFrontRegardless()
            panels.append(panel)
            if NSMouseInRect(mouse, frame, false) {
                panel.makeKey()
                if fullScreen { view.selectAll() }
            }
        }
        if panels.isEmpty {
            close()
            return
        }
        if !panels.contains(where: \.isKeyWindow) { panels[0].makeKey() }
    }

    func finish(_ action: Action) {
        guard action != .cancel, let view = activeView, let image = view.renderSelection(),
              let screen = view.window?.screen, let selection = view.selection else {
            close()
            return
        }
        let frame = screen.frame
        let onScreen = CGRect(x: frame.minX + selection.minX, y: frame.maxY - selection.maxY,
                              width: selection.width, height: selection.height)
        close()
        switch action {
        case .copy:
            Output.copy(image, scale: view.shot.scale)
            if Settings.shared.autoSave { Output.save(image, scale: view.shot.scale, copied: true) }
        case .save: Output.save(image, scale: view.shot.scale)
        case .pin: PinWindow.show(image, scale: view.shot.scale, frame: onScreen)
        case .cancel, .undo: break
        }
    }

    private func close() {
        panels.forEach { $0.orderOut(nil) }
        panels = []
        activeView = nil
        NSCursor.arrow.set()
        CaptureSession.current = nil
        let onEnd = onEnd
        self.onEnd = nil
        onEnd?()
    }
}

final class OverlayPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}
