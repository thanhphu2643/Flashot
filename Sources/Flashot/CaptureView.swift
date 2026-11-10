import AppKit

/// One screen of a capture: the frozen image, the selection with its handles, the marks
/// drawn on it and the toolbar. Coordinates are points with a top-left origin.
@MainActor
final class CaptureView: NSView, NSTextFieldDelegate {
    private enum Drag {
        case create(CGPoint)
        case move(CGPoint, CGRect)
        case resize(Handle, CGRect)
        case draw(CGPoint)
    }

    private struct Handle: OptionSet {
        let rawValue: Int
        static let left = Handle(rawValue: 1), right = Handle(rawValue: 2)
        static let top = Handle(rawValue: 4), bottom = Handle(rawValue: 8)
    }

    let shot: Shot
    private unowned let session: CaptureSession
    private let windowFrames: [CGRect]
    private var image: NSImage?

    private(set) var selection: CGRect?
    private var hover: CGRect?
    private var drag: Drag?
    private var annotations: [Annotation] = []
    private var pending: Annotation?
    private var tool: Tool?
    private var style = Style()
    private var toolbar: Toolbar?
    private var textField: NSTextField?
    private var textOrigin: CGPoint = .zero

    private let accent = NSColor(red: 0.13, green: 0.47, blue: 1, alpha: 1)

    init(session: CaptureSession, shot: Shot, windowFrames: [CGRect]) {
        self.session = session
        self.shot = shot
        self.windowFrames = windowFrames
        super.init(frame: .zero)
        rebuildImage()
        addTrackingArea(NSTrackingArea(rect: .zero, options: [.activeAlways, .inVisibleRect, .mouseMoved], owner: self))
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is unused") }

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func viewDidMoveToWindow() { window?.makeFirstResponder(self) }

    func selectAll() {
        selection = bounds.isEmpty ? window?.frame.size.rect : bounds
        session.activeView = self
        showToolbar()
        needsDisplay = true
    }

    // MARK: Mouse

    override func mouseMoved(with event: NSEvent) {
        let p = point(event)
        if selection == nil {
            let found = windowFrames.first { $0.contains(p) } ?? bounds
            if found != hover {
                hover = found
                needsDisplay = true
            }
        }
        cursor(at: p).set()
    }

    override func mouseDown(with event: NSEvent) {
        if let active = session.activeView, active !== self { return }
        let p = point(event)
        if textField != nil {
            commitText()
            return
        }
        guard let selection else {
            drag = .create(p)
            return
        }
        if event.clickCount == 2, selection.contains(p), tool == nil {
            session.finish(.copy)
            return
        }
        if let tool, selection.contains(p) {
            switch tool {
            case .text: beginText(at: p)
            case .counter:
                annotations.append(.counter(annotations.filter(\.isCounter).count + 1, p, style))
                needsDisplay = true
            default: drag = .draw(p)
            }
            return
        }
        let handle = handle(at: p, in: selection)
        if !handle.isEmpty {
            drag = .resize(handle, selection)
        } else if selection.contains(p) {
            drag = .move(p, selection)
        } else if annotations.isEmpty {
            drag = .create(p)
        }
    }

    override func mouseDragged(with event: NSEvent) {
        let p = point(event).clamped(to: bounds)
        switch drag {
        case let .create(start):
            selection = CGRect(corners: start, p)
            session.activeView = self
            toolbar?.isHidden = true
        case let .move(start, original):
            var r = original.offsetBy(dx: p.x - start.x, dy: p.y - start.y)
            r.origin.x = min(max(0, r.minX), bounds.width - r.width)
            r.origin.y = min(max(0, r.minY), bounds.height - r.height)
            selection = r
            toolbar?.isHidden = true
        case let .resize(handle, original):
            var (x0, y0, x1, y1) = (original.minX, original.minY, original.maxX, original.maxY)
            if handle.contains(.left) { x0 = p.x }
            if handle.contains(.right) { x1 = p.x }
            if handle.contains(.top) { y0 = p.y }
            if handle.contains(.bottom) { y1 = p.y }
            selection = CGRect(corners: CGPoint(x: x0, y: y0), CGPoint(x: x1, y: y1))
            toolbar?.isHidden = true
        case let .draw(start):
            pending = annotation(from: start, to: p)
        case nil:
            return
        }
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        defer {
            drag = nil
            needsDisplay = true
        }
        switch drag {
        case .create:
            if let s = selection, s.width < 4 || s.height < 4 {
                selection = nil
            }
            if selection == nil {
                // A click without a drag takes the window under the pointer, or the whole screen.
                selection = hover ?? bounds
            }
            session.activeView = self
            showToolbar()
        case .move, .resize:
            showToolbar()
        case .draw:
            if let pending, !pending.isEmpty {
                annotations.append(pending)
                if pending.mosaic != nil { rebuildImage() }
            }
            pending = nil
        case nil:
            break
        }
    }

    override func rightMouseDown(with event: NSEvent) {
        // First step back to choosing a region, as long as nothing has been drawn yet.
        if selection != nil, annotations.isEmpty, textField == nil {
            selection = nil
            session.activeView = nil
            toolbar?.removeFromSuperview()
            toolbar = nil
            tool = nil
            mouseMoved(with: event)
        } else {
            session.finish(.cancel)
        }
    }

    // MARK: Keyboard

    override func keyDown(with event: NSEvent) {
        let command = event.modifierFlags.contains(.command)
        switch (event.keyCode, command, event.charactersIgnoringModifiers?.lowercased() ?? "") {
        case (53, _, _): session.finish(.cancel) // Esc
        case (36, _, _), (76, _, _), (_, true, "c"): finishIfSelected(.copy) // Return, Enter, ⌘C
        case (_, true, "s"): finishIfSelected(.save)
        case (_, true, "p"): finishIfSelected(.pin)
        case (_, true, "z"): undo()
        case (_, true, "a"): selectAll()
        case let (_, command, key):
            if !command, selection != nil, let tool = Tool.allCases.first(where: { $0.key == key }) {
                toolbar?.pick(tool)
            } else {
                super.keyDown(with: event)
            }
        }
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard window?.firstResponder === self, event.modifierFlags.contains(.command) else {
            return super.performKeyEquivalent(with: event)
        }
        keyDown(with: event)
        return true
    }

    private func finishIfSelected(_ action: Action) {
        if selection != nil { session.finish(action) }
    }

    private func undo() {
        guard let last = annotations.popLast() else { return }
        if last.mosaic != nil { rebuildImage() }
        needsDisplay = true
    }

    // MARK: Text

    private func beginText(at p: CGPoint) {
        let field = NSTextField(string: "")
        field.font = style.font
        field.textColor = style.color
        field.isBordered = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.delegate = self
        field.cell?.isScrollable = true
        field.frame = CGRect(x: p.x, y: p.y - style.fontSize * 0.7, width: 60, height: style.fontSize * 1.4)
        addSubview(field)
        window?.makeFirstResponder(field)
        textField = field
        textOrigin = field.frame.origin
    }

    func controlTextDidChange(_ notification: Notification) {
        guard let field = textField else { return }
        let width = (field.attributedStringValue.size().width + 20).rounded()
        field.setFrameSize(CGSize(width: max(60, width), height: field.frame.height))
    }

    func controlTextDidEndEditing(_ notification: Notification) { commitText() }

    private func commitText() {
        guard let field = textField else { return }
        textField = nil
        let text = field.stringValue
        field.removeFromSuperview()
        // NSTextField insets its text by about 2 points.
        if !text.isEmpty { annotations.append(.text(text, textOrigin.applying(.init(translationX: 2, y: 0)), style)) }
        window?.makeFirstResponder(self)
        needsDisplay = true
    }

    // MARK: Toolbar

    private func showToolbar() {
        guard let selection else { return }
        let bar = toolbar ?? makeToolbar()
        bar.isHidden = false
        bar.layout(around: selection, in: bounds)
    }

    private func makeToolbar() -> Toolbar {
        let bar = Toolbar()
        bar.onTool = { [weak self] tool in
            self?.commitText()
            self?.tool = tool
            self?.showToolbar() // the options column changes the width
        }
        bar.onStyle = { [weak self] style in
            self?.style = style
            self?.textField?.textColor = style.color
            self?.textField?.font = style.font
            self?.showToolbar()
        }
        bar.onAction = { [weak self] action in
            guard let self else { return }
            if action == .undo { undo() } else { commitText(); session.finish(action) }
        }
        bar.install(in: self)
        toolbar = bar
        return bar
    }

    // MARK: Drawing

    private func annotation(from a: CGPoint, to b: CGPoint) -> Annotation? {
        switch tool {
        case .rect: .rect(CGRect(corners: a, b), style)
        case .ellipse: .ellipse(CGRect(corners: a, b), style)
        case .arrow: .arrow(a, b, style)
        case .pen:
            if case let .pen(points, s)? = pending { .pen(points + [b], s) } else { .pen([a, b], style) }
        case .mosaic: .mosaic(CGRect(corners: a, b), blur: false)
        case .blur: .mosaic(CGRect(corners: a, b), blur: true)
        case .text, .counter, nil: nil
        }
    }

    private func rebuildImage() {
        guard let cg = shot.render(mosaics: annotations.compactMap(\.mosaic)) else { return }
        image = NSImage(cgImage: cg, size: CGSize(width: CGFloat(cg.width) / shot.scale, height: CGFloat(cg.height) / shot.scale))
    }

    override func draw(_ dirtyRect: NSRect) {
        image?.draw(in: bounds, from: .zero, operation: .copy, fraction: 1, respectFlipped: true, hints: nil)

        let focus = selection ?? hover
        NSColor.black.withAlphaComponent(0.4).setFill()
        let dim = NSBezierPath(rect: bounds)
        if let focus { dim.appendRect(focus) }
        dim.windingRule = .evenOdd
        dim.fill()

        guard let focus else { return }
        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(rect: focus).addClip()
        annotations.forEach { $0.draw() }
        if let pending {
            if let mosaic = pending.mosaic {
                // Preview only the outline; the pixels change on mouse-up.
                NSColor.white.withAlphaComponent(0.8).setStroke()
                let outline = NSBezierPath(rect: mosaic.rect)
                outline.setLineDash([4, 3], count: 2, phase: 0)
                outline.stroke()
            } else {
                pending.draw()
            }
        }
        NSGraphicsContext.restoreGraphicsState()

        let border = NSBezierPath(rect: focus.insetBy(dx: 0.5, dy: 0.5))
        border.lineWidth = selection == nil ? 3 : 1.5
        if selection != nil { border.setLineDash([5, 3], count: 2, phase: 0) }
        accent.setStroke()
        border.stroke()

        if let selection {
            accent.setFill()
            for p in handlePoints(selection) {
                NSBezierPath(ovalIn: CGRect(x: p.x - 4, y: p.y - 4, width: 8, height: 8)).fill()
            }
            drawSizeLabel(selection)
        }
    }

    private func drawSizeLabel(_ r: CGRect) {
        let text = NSAttributedString(string: "\(Int(r.width.rounded())) × \(Int(r.height.rounded()))", attributes: [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .medium),
            .foregroundColor: NSColor.white,
        ])
        let size = text.size()
        var box = CGRect(x: r.minX, y: r.minY - size.height - 10, width: size.width + 12, height: size.height + 4)
        if box.minY < 0 { box.origin.y = r.minY + 6; box.origin.x += 6 }
        NSColor.black.withAlphaComponent(0.7).setFill()
        NSBezierPath(roundedRect: box, xRadius: 4, yRadius: 4).fill()
        text.draw(at: CGPoint(x: box.minX + 6, y: box.minY + 2))
    }

    // MARK: Export

    /// The selected pixels with every mark burned in.
    func renderSelection() -> CGImage? {
        commitText()
        guard let selection, let base = shot.render(mosaics: annotations.compactMap(\.mosaic)) else { return nil }
        let s = shot.scale
        let pixels = CGRect(x: selection.minX * s, y: selection.minY * s, width: selection.width * s, height: selection.height * s)
            .integral.intersection(CGRect(x: 0, y: 0, width: base.width, height: base.height))
        guard let cropped = base.cropping(to: pixels),
              let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(data: nil, width: cropped.width, height: cropped.height, bitsPerComponent: 8,
                                      bytesPerRow: 0, space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        let size = CGSize(width: cropped.width, height: cropped.height)
        context.draw(cropped, in: CGRect(origin: .zero, size: size))
        context.translateBy(x: 0, y: size.height)
        context.scaleBy(x: s, y: -s)
        context.translateBy(x: -pixels.minX / s, y: -pixels.minY / s)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)
        annotations.forEach { $0.draw() }
        NSGraphicsContext.restoreGraphicsState()
        return context.makeImage()
    }

    // MARK: Geometry

    private func point(_ event: NSEvent) -> CGPoint { convert(event.locationInWindow, from: nil) }

    private func handlePoints(_ r: CGRect) -> [CGPoint] {
        [CGPoint(x: r.minX, y: r.minY), CGPoint(x: r.midX, y: r.minY), CGPoint(x: r.maxX, y: r.minY),
         CGPoint(x: r.minX, y: r.midY), CGPoint(x: r.maxX, y: r.midY),
         CGPoint(x: r.minX, y: r.maxY), CGPoint(x: r.midX, y: r.maxY), CGPoint(x: r.maxX, y: r.maxY)]
    }

    private func handle(at p: CGPoint, in r: CGRect) -> Handle {
        let grab: CGFloat = 6
        guard r.insetBy(dx: -grab, dy: -grab).contains(p) else { return [] }
        var handle: Handle = []
        if abs(p.x - r.minX) <= grab { handle.insert(.left) } else if abs(p.x - r.maxX) <= grab { handle.insert(.right) }
        if abs(p.y - r.minY) <= grab { handle.insert(.top) } else if abs(p.y - r.maxY) <= grab { handle.insert(.bottom) }
        return handle
    }

    private func cursor(at p: CGPoint) -> NSCursor {
        guard let selection else { return .crosshair }
        if textField != nil { return .iBeam }
        if let tool, selection.contains(p) { return tool == .text ? .iBeam : .crosshair }
        let h = handle(at: p, in: selection)
        if h == [.left] || h == [.right] { return .resizeLeftRight }
        if h == [.top] || h == [.bottom] { return .resizeUpDown }
        if !h.isEmpty { return .crosshair }
        return selection.contains(p) ? .openHand : (annotations.isEmpty ? .crosshair : .arrow)
    }
}

private extension CGRect {
    init(corners a: CGPoint, _ b: CGPoint) {
        self.init(x: min(a.x, b.x), y: min(a.y, b.y), width: abs(b.x - a.x), height: abs(b.y - a.y))
    }
}

private extension CGSize {
    var rect: CGRect { CGRect(origin: .zero, size: self) }
}

private extension CGPoint {
    func clamped(to r: CGRect) -> CGPoint {
        CGPoint(x: min(max(r.minX, x), r.maxX), y: min(max(r.minY, y), r.maxY))
    }
}
