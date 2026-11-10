import AppKit
import Observation

/// Screenshots in the save folder, newest first.
@MainActor
@Observable
final class History {
    static let shared = History()

    struct Item: Identifiable, Hashable {
        let url: URL
        let date: Date
        var id: URL { url }
    }

    private(set) var items: [Item] = []

    func reload() {
        let keys: [URLResourceKey] = [.creationDateKey]
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: Settings.shared.folder, includingPropertiesForKeys: keys, options: .skipsHiddenFiles)) ?? []
        items = urls
            .filter { ["png", "jpg", "jpeg"].contains($0.pathExtension.lowercased()) }
            .map { Item(url: $0, date: (try? $0.resourceValues(forKeys: Set(keys)).creationDate) ?? .distantPast) }
            .sorted { $0.date > $1.date }
    }

    func copy(_ item: Item) {
        guard let (image, scale) = load(item) else { return }
        Output.copy(image, scale: scale)
    }

    func pin(_ item: Item) {
        guard let (image, scale) = load(item) else { return }
        let size = CGSize(width: CGFloat(image.width) / scale, height: CGFloat(image.height) / scale)
        let visible = (NSScreen.main ?? NSScreen.screens[0]).visibleFrame
        PinWindow.show(image, scale: scale, frame: CGRect(x: visible.midX - size.width / 2, y: visible.midY - size.height / 2,
                                                          width: size.width, height: size.height))
    }

    func trash(_ item: Item) {
        try? FileManager.default.trashItem(at: item.url, resultingItemURL: nil)
        reload()
    }

    private func load(_ item: Item) -> (CGImage, CGFloat)? {
        guard let image = NSImage(contentsOf: item.url),
              let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        return (cg, CGFloat(cg.width) / max(image.size.width, 1))
    }
}
