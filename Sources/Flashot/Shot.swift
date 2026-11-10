import AppKit
import CShotCore

/// A frozen screen image plus a working pixel buffer that the mosaic tools paint into.
final class Shot {
    let scale: CGFloat
    private let context: CGContext
    private let pristine: Data

    init?(_ image: CGImage, scale: CGFloat) {
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                data: nil, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: 0,
                space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ),
              let data = context.data else { return nil }
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        self.scale = scale
        self.context = context
        pristine = Data(bytes: data, count: context.bytesPerRow * context.height)
    }

    /// The screen image with every mosaic applied (rectangles in points, top-left origin).
    func render(mosaics: [(rect: CGRect, blur: Bool)]) -> CGImage? {
        guard let data = context.data?.assumingMemoryBound(to: UInt8.self) else { return nil }
        pristine.withUnsafeBytes { data.update(from: $0.bindMemory(to: UInt8.self).baseAddress!, count: $0.count) }
        let (width, height, stride) = (context.width, context.height, context.bytesPerRow)
        for mosaic in mosaics {
            let r = CGRect(x: mosaic.rect.minX * scale, y: mosaic.rect.minY * scale,
                           width: mosaic.rect.width * scale, height: mosaic.rect.height * scale)
                .integral.intersection(CGRect(x: 0, y: 0, width: width, height: height))
            guard !r.isEmpty else { continue }
            let (x, y, w, h) = (Int(r.minX), Int(r.minY), Int(r.width), Int(r.height))
            if mosaic.blur {
                shot_blur(data, width, height, stride, x, y, w, h, Int(10 * scale))
            } else {
                shot_pixelate(data, width, height, stride, x, y, w, h, Int(10 * scale))
            }
        }
        return context.makeImage()
    }
}
