import AppKit
import SwiftUI

/// Loads the current desktop wallpaper and extracts a small palette of dominant colors.
enum WallpaperPalette {

    /// Returns the current wallpaper image for the main screen, if available.
    static func currentWallpaperImage() -> NSImage? {
        guard
            let screen = NSScreen.main,
            let url = NSWorkspace.shared.desktopImageURL(for: screen)
        else { return nil }
        return NSImage(contentsOf: url)
    }

    /// Extracts up to `count` distinct dominant colors from the current wallpaper.
    /// The image lookup is main-actor only; the pixel work is a tiny 64×64 pass.
    static func dominantColors(count: Int = 8) async -> [Color] {
        guard
            let image = currentWallpaperImage(),
            let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
        else { return [] }
        return dominantColors(from: cgImage, count: count).map { Color(rgb: $0) }
    }

    /// Quantizes the image into color buckets and greedily selects visually distinct ones.
    nonisolated static func dominantColors(from cgImage: CGImage, count: Int) -> [RGB] {
        let side = 64
        let bytesPerPixel = 4
        let bytesPerRow = side * bytesPerPixel
        var pixels = [UInt8](repeating: 0, count: side * side * bytesPerPixel)

        guard
            let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
            let context = CGContext(
                data: &pixels,
                width: side,
                height: side,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
        else { return [] }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: side, height: side))

        // Histogram, quantizing each channel to 5 bits (32 levels) to merge near colors.
        var histogram: [Int: (count: Int, sum: (r: Int, g: Int, b: Int))] = [:]
        for index in stride(from: 0, to: pixels.count, by: bytesPerPixel) {
            let r = Int(pixels[index])
            let g = Int(pixels[index + 1])
            let b = Int(pixels[index + 2])
            let key = (r >> 3) << 10 | (g >> 3) << 5 | (b >> 3)
            var entry = histogram[key] ?? (0, (0, 0, 0))
            entry.count += 1
            entry.sum = (entry.sum.r + r, entry.sum.g + g, entry.sum.b + b)
            histogram[key] = entry
        }

        // Average each bucket and sort by popularity.
        let candidates = histogram.values
            .map { entry -> (rgb: RGB, count: Int) in
                let c = entry.count
                return (RGB(red: entry.sum.r / c, green: entry.sum.g / c, blue: entry.sum.b / c), c)
            }
            .sorted { $0.count > $1.count }

        // Greedily pick colors that are far enough apart to keep the palette varied.
        var selected: [RGB] = []
        let minDistanceSquared = 40 * 40
        for candidate in candidates {
            if selected.allSatisfy({ distanceSquared($0, candidate.rgb) > minDistanceSquared }) {
                selected.append(candidate.rgb)
                if selected.count == count { break }
            }
        }
        return selected
    }

    private nonisolated static func distanceSquared(_ a: RGB, _ b: RGB) -> Int {
        let dr = a.red - b.red
        let dg = a.green - b.green
        let db = a.blue - b.blue
        return dr * dr + dg * dg + db * db
    }
}

extension Color {
    init(rgb: RGB) {
        self.init(
            .sRGB,
            red: Double(rgb.red) / 255,
            green: Double(rgb.green) / 255,
            blue: Double(rgb.blue) / 255,
            opacity: 1
        )
    }

    /// Converts to 0–255 sRGB components.
    var rgb255: RGB {
        let nsColor = NSColor(self).usingColorSpace(.sRGB) ?? NSColor.black
        return RGB(
            red: Int((nsColor.redComponent * 255).rounded()),
            green: Int((nsColor.greenComponent * 255).rounded()),
            blue: Int((nsColor.blueComponent * 255).rounded())
        )
    }
}
