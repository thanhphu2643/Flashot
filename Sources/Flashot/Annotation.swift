import AppKit

enum Tool: CaseIterable {
    case rect, ellipse, arrow, pen, text, counter, mosaic, blur

    var symbol: String {
        switch self {
        case .rect: "rectangle"
        case .ellipse: "circle"
        case .arrow: "arrow.up.right"
        case .pen: "scribble"
        case .text: "textformat"
        case .counter: "1.circle"
        case .mosaic: "checkerboard.rectangle"
        case .blur: "drop"
        }
    }

    var key: String {
        switch self {
        case .rect: "r"
        case .ellipse: "e"
        case .arrow: "a"
        case .pen: "p"
        case .text: "t"
        case .counter: "n"
        case .mosaic: "m"
        case .blur: "b"
        }
    }

    var title: String {
        switch self {
        case .rect: "Hình chữ nhật"
        case .ellipse: "Hình elip"
        case .arrow: "Mũi tên"
        case .pen: "Bút vẽ"
        case .text: "Chữ"
        case .counter: "Đánh số"
        case .mosaic: "Làm mờ ô vuông"
        case .blur: "Làm nhòe"
        }
    }

    /// Mosaic tools change the pixels underneath instead of drawing on top.
    var paintsPixels: Bool { self == .mosaic || self == .blur }
}

struct Style {
    var color: NSColor = .systemRed
    var width: CGFloat = 4

    var fontSize: CGFloat { 10 + width * 3 }
    var font: NSFont { .systemFont(ofSize: fontSize, weight: .semibold) }
}

/// Shapes in screen points with a top-left origin. Drawn into the current (flipped) context.
enum Annotation {
    case rect(CGRect, Style)
    case ellipse(CGRect, Style)
    case arrow(CGPoint, CGPoint, Style)
    case pen([CGPoint], Style)
    case text(String, CGPoint, Style)
    case counter(Int, CGPoint, Style)
    case mosaic(CGRect, blur: Bool)

    var mosaic: (rect: CGRect, blur: Bool)? {
        if case let .mosaic(rect, blur) = self { return (rect, blur) }
        return nil
    }

    var isCounter: Bool {
        if case .counter = self { return true }
        return false
    }

    /// Too small to be anything but a stray click.
    var isEmpty: Bool {
        switch self {
        case let .rect(r, _), let .ellipse(r, _), let .mosaic(r, _): r.width < 3 || r.height < 3
        case let .arrow(a, b, _): hypot(b.x - a.x, b.y - a.y) < 4
        case let .pen(points, _): points.count < 2
        case let .text(s, _, _): s.isEmpty
        case .counter: false
        }
    }

    func draw() {
        switch self {
        case let .rect(r, style):
            style.color.setStroke()
            let path = NSBezierPath(rect: r)
            path.lineWidth = style.width
            path.lineJoinStyle = .round
            path.stroke()
        case let .ellipse(r, style):
            style.color.setStroke()
            let path = NSBezierPath(ovalIn: r)
            path.lineWidth = style.width
            path.stroke()
        case let .arrow(a, b, style):
            Annotation.drawArrow(from: a, to: b, style)
        case let .pen(points, style):
            style.color.setStroke()
            let path = NSBezierPath()
            path.move(to: points[0])
            points.dropFirst().forEach { path.line(to: $0) }
            path.lineWidth = style.width
            path.lineCapStyle = .round
            path.lineJoinStyle = .round
            path.stroke()
        case let .text(string, origin, style):
            NSAttributedString(string: string, attributes: [.font: style.font, .foregroundColor: style.color])
                .draw(at: origin)
        case let .counter(number, center, style):
            let radius = 9 + style.width * 1.5
            style.color.setFill()
            NSBezierPath(ovalIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)).fill()
            let label = NSAttributedString(string: "\(number)", attributes: [
                .font: NSFont.systemFont(ofSize: radius * 1.1, weight: .bold),
                .foregroundColor: style.color.isLight ? NSColor.black : NSColor.white,
            ])
            let size = label.size()
            label.draw(at: CGPoint(x: center.x - size.width / 2, y: center.y - size.height / 2))
        case .mosaic:
            break
        }
    }

    private static func drawArrow(from a: CGPoint, to b: CGPoint, _ style: Style) {
        let angle = atan2(b.y - a.y, b.x - a.x)
        let length = hypot(b.x - a.x, b.y - a.y)
        let head = min(max(12, style.width * 4), length)
        let spread = CGFloat.pi / 7
        let base = CGPoint(x: b.x - cos(angle) * head * 0.8, y: b.y - sin(angle) * head * 0.8)
        style.color.set()

        let shaft = NSBezierPath()
        shaft.move(to: a)
        shaft.line(to: base)
        shaft.lineWidth = style.width
        shaft.lineCapStyle = .round
        shaft.stroke()

        let tip = NSBezierPath()
        tip.move(to: b)
        tip.line(to: CGPoint(x: b.x - cos(angle - spread) * head, y: b.y - sin(angle - spread) * head))
        tip.line(to: CGPoint(x: b.x - cos(angle + spread) * head, y: b.y - sin(angle + spread) * head))
        tip.close()
        tip.lineJoinStyle = .round
        tip.lineWidth = 1
        tip.fill()
        tip.stroke()
    }
}

extension NSColor {
    var isLight: Bool {
        guard let c = usingColorSpace(.sRGB) else { return false }
        return 0.299 * c.redComponent + 0.587 * c.greenComponent + 0.114 * c.blueComponent > 0.7
    }
}
