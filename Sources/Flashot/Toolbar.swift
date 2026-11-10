import AppKit

enum Action { case copy, save, pin, cancel, undo }

/// Two bars hugging one corner of the selection, like Zalo's: a vertical bar of drawing
/// tools beside it (plus a size/color column for the chosen tool) and a horizontal bar of
/// actions under or over it.
@MainActor
final class Toolbar {
    enum Corner: CaseIterable { case bottomRight, bottomLeft, topRight, topLeft }

    static let colors: [NSColor] = [.systemRed, .systemOrange, .systemYellow, .systemGreen, .systemBlue, .white, .black]
    static let widths: [CGFloat] = [2, 4, 7]

    var onTool: ((Tool?) -> Void)?
    var onStyle: ((Style) -> Void)?
    var onAction: ((Action) -> Void)?

    private(set) var tool: Tool?
    private(set) var style = Style()

    let toolsBar = Bar()
    let actionsBar = Bar()
    private let toolColumn = NSStackView()
    private let optionsColumn = NSStackView()
    private var toolButtons: [Tool: NSButton] = [:]
    private var colorButtons: [NSButton] = []
    private var widthButtons: [NSButton] = []
    private var optionsOnLeft = false

    var isHidden = false {
        didSet { [toolsBar, actionsBar].forEach { $0.isHidden = isHidden } }
    }

    init() {
        let tools = Tool.allCases.map { tool in
            let button = Toolbar.iconButton(tool.symbol, "\(tool.title) (\(tool.key.uppercased()))") { [weak self] in self?.pick(tool) }
            toolButtons[tool] = button
            return button
        }
        let undo = Toolbar.iconButton("arrow.uturn.backward", "Hoàn tác (⌘Z)") { [weak self] in self?.onAction?(.undo) }
        toolColumn.setViews(tools + [Toolbar.separator(vertical: false), undo], in: .top)
        toolColumn.orientation = .vertical
        toolColumn.spacing = 2

        widthButtons = Toolbar.widths.map { width in
            let button = Toolbar.iconButton("circle.fill", "Cỡ \(Int(width))") { [weak self] in self?.setWidth(width) }
            button.image = NSImage(systemSymbolName: "circle.fill", accessibilityDescription: nil)?
                .withSymbolConfiguration(.init(pointSize: 4 + width * 1.6, weight: .regular))
            return button
        }
        colorButtons = Toolbar.colors.map { color in Swatch(color: color) { [weak self] in self?.setColor(color) } }
        optionsColumn.setViews(widthButtons + [Toolbar.separator(vertical: false)] + colorButtons, in: .top)
        optionsColumn.orientation = .vertical
        optionsColumn.spacing = 6
        optionsColumn.isHidden = true
        toolsBar.set([toolColumn, optionsColumn], vertical: false)

        actionsBar.set([
            Toolbar.iconButton("xmark", "Huỷ (Esc)") { [weak self] in self?.onAction?(.cancel) },
            Toolbar.iconButton("pin", "Ghim lên màn hình (⌘P)") { [weak self] in self?.onAction?(.pin) },
            Toolbar.iconButton("square.and.arrow.down", "Lưu (⌘S)") { [weak self] in self?.onAction?(.save) },
            Toolbar.iconButton("doc.on.doc", "Sao chép (⌘C)") { [weak self] in self?.onAction?(.copy) },
            Toolbar.iconButton("checkmark", "Xong — sao chép (Enter)", tint: .systemGreen) { [weak self] in self?.onAction?(.copy) },
        ], vertical: false)
        refresh()
    }

    func install(in view: NSView) {
        view.addSubview(toolsBar)
        view.addSubview(actionsBar)
    }

    func removeFromSuperview() {
        toolsBar.removeFromSuperview()
        actionsBar.removeFromSuperview()
    }

    /// Hugs the first corner, in `Corner` order, where both bars fit on screen;
    /// with no room outside (a full-screen selection) both go inside the bottom-right corner.
    func layout(around selection: CGRect, in bounds: CGRect) {
        let room = bounds.insetBy(dx: 2, dy: 2)
        for corner in Corner.allCases {
            setOptionsOnLeft(corner == .bottomLeft || corner == .topLeft)
            let (tools, actions) = frames(corner, selection)
            if room.contains(tools), room.contains(actions) {
                toolsBar.frame = tools
                actionsBar.frame = actions
                return
            }
        }
        setOptionsOnLeft(false)
        let (t, a) = (toolsBar.frame.size, actionsBar.frame.size)
        let gap: CGFloat = 6
        let actions = CGRect(x: selection.maxX - gap - a.width, y: selection.maxY - gap - a.height, width: a.width, height: a.height)
        let tools = CGRect(x: selection.maxX - gap - t.width, y: actions.minY - gap - t.height, width: t.width, height: t.height)
        toolsBar.frame = tools.clamped(to: room)
        actionsBar.frame = actions.clamped(to: room)
    }

    private func frames(_ corner: Corner, _ s: CGRect) -> (CGRect, CGRect) {
        let (t, a) = (toolsBar.frame.size, actionsBar.frame.size)
        let right = corner == .bottomRight || corner == .topRight
        let bottom = corner == .bottomRight || corner == .bottomLeft
        // One point out so the bars sit just outside the dashed border.
        let tools = CGRect(x: right ? s.maxX + 1 : s.minX - 1 - t.width,
                           y: bottom ? s.maxY - t.height : s.minY,
                           width: t.width, height: t.height)
        let actions = CGRect(x: right ? s.maxX - a.width : s.minX,
                             y: bottom ? s.maxY + 1 : s.minY - 1 - a.height,
                             width: a.width, height: a.height)
        return (tools, actions)
    }

    func pick(_ tool: Tool?) {
        self.tool = self.tool == tool ? nil : tool
        refresh()
        onTool?(self.tool)
    }

    private func setColor(_ color: NSColor) {
        style.color = color
        refresh()
        onStyle?(style)
    }

    private func setWidth(_ width: CGFloat) {
        style.width = width
        refresh()
        onStyle?(style)
    }

    /// Keeps the size/color column on the outside, away from the selection.
    private func setOptionsOnLeft(_ left: Bool) {
        guard left != optionsOnLeft else { return }
        optionsOnLeft = left
        toolsBar.set(left ? [optionsColumn, toolColumn] : [toolColumn, optionsColumn], vertical: false)
    }

    private func refresh() {
        for (tool, button) in toolButtons {
            button.layer?.backgroundColor = tool == self.tool ? NSColor.controlAccentColor.cgColor : nil
        }
        for (button, color) in zip(colorButtons, Toolbar.colors) {
            button.layer?.borderColor = (color == style.color ? NSColor.white : NSColor(white: 1, alpha: 0.25)).cgColor
            button.layer?.borderWidth = color == style.color ? 2 : 1
        }
        for (button, width) in zip(widthButtons, Toolbar.widths) {
            button.contentTintColor = width == style.width ? .controlAccentColor : .white
        }
        optionsColumn.isHidden = tool == nil || tool!.paintsPixels
        toolsBar.fit()
        actionsBar.fit()
    }

    private static func iconButton(_ symbol: String, _ tip: String, tint: NSColor = .white, action: @escaping () -> Void) -> NSButton {
        let button = ClosureButton(action: action)
        button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: tip)?
            .withSymbolConfiguration(.init(pointSize: 16, weight: .medium))
        button.toolTip = tip
        button.contentTintColor = tint
        button.isBordered = false
        button.wantsLayer = true
        button.layer?.cornerRadius = 5
        button.widthAnchor.constraint(equalToConstant: 32).isActive = true
        button.heightAnchor.constraint(equalToConstant: 30).isActive = true
        return button
    }

    private static func separator(vertical: Bool) -> NSView {
        let line = NSBox()
        line.boxType = .custom
        line.fillColor = NSColor(white: 1, alpha: 0.2)
        line.borderWidth = 0
        line.widthAnchor.constraint(equalToConstant: vertical ? 1 : 22).isActive = true
        line.heightAnchor.constraint(equalToConstant: vertical ? 22 : 1).isActive = true
        return line
    }
}

/// A dark panel holding a stack of buttons.
final class Bar: NSView {
    private let stack = NSStackView()

    init() {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = NSColor(white: 0.12, alpha: 0.96).cgColor
        layer?.cornerRadius = 6
        layer?.borderColor = NSColor(white: 1, alpha: 0.1).cgColor
        layer?.borderWidth = 1
        stack.alignment = .top
        stack.spacing = 6
        stack.edgeInsets = NSEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is unused") }

    override var isFlipped: Bool { true }
    // Clicks between buttons must not reach the capture view underneath.
    override func mouseDown(with event: NSEvent) {}
    override func rightMouseDown(with event: NSEvent) {}

    func set(_ views: [NSView], vertical: Bool) {
        stack.orientation = vertical ? .vertical : .horizontal
        stack.setViews(views, in: .top)
        fit()
    }

    func fit() {
        setFrameSize(stack.fittingSize)
    }
}

private class ClosureButton: NSButton {
    private let handler: () -> Void

    init(action: @escaping () -> Void) {
        handler = action
        super.init(frame: .zero)
        target = self
        self.action = #selector(fire)
        title = ""
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is unused") }

    @objc private func fire() { handler() }
}

private final class Swatch: ClosureButton {
    init(color: NSColor, action: @escaping () -> Void) {
        super.init(action: action)
        isBordered = false
        wantsLayer = true
        layer?.backgroundColor = color.cgColor
        layer?.cornerRadius = 9
        widthAnchor.constraint(equalToConstant: 18).isActive = true
        heightAnchor.constraint(equalToConstant: 18).isActive = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is unused") }
}

private extension CGRect {
    func clamped(to room: CGRect) -> CGRect {
        CGRect(x: min(max(room.minX, minX), room.maxX - width), y: min(max(room.minY, minY), room.maxY - height),
               width: width, height: height)
    }
}
