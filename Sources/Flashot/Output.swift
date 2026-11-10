import AppKit

@MainActor
enum Output {
    static var folder: URL { Settings.shared.folder }

    static func png(_ image: CGImage, scale: CGFloat) -> Data? {
        let rep = NSBitmapImageRep(cgImage: image)
        // Points, so a Retina shot pastes at its on-screen size.
        rep.size = NSSize(width: CGFloat(image.width) / scale, height: CGFloat(image.height) / scale)
        return rep.representation(using: .png, properties: [:])
    }

    static func copy(_ image: CGImage, scale: CGFloat) {
        guard let data = png(image, scale: scale) else { return }
        let board = NSPasteboard.general
        board.clearContents()
        board.setData(data, forType: .png)
        if let tiff = NSImage(data: data)?.tiffRepresentation { board.setData(tiff, forType: .tiff) }
        Toast.show("Đã chép ảnh vào bộ nhớ tạm")
    }

    static func save(_ image: CGImage, scale: CGFloat, copied: Bool = false) {
        guard let data = png(image, scale: scale) else { return }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd 'lúc' HH.mm.ss"
        let url = folder.appendingPathComponent("Flashot \(formatter.string(from: Date())).png")
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try data.write(to: url)
            History.shared.reload()
            Toast.show("\(copied ? "Đã chép và lưu" : "Đã lưu") \(url.lastPathComponent)") { NSWorkspace.shared.activateFileViewerSelecting([url]) }
        } catch {
            Toast.show("Không lưu được ảnh: \(error.localizedDescription)")
        }
    }
}
