import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Shrinks and recompresses imported photos before they're saved, so a
/// recipe page's 6000-pixel hero image doesn't fill the library and the
/// person's iCloud storage. Uses ImageIO, so it never decodes the full image
/// into memory.
public enum RecipePhotoProcessor {
    /// Saved photos are at most this many pixels on their long edge.
    public static let maxPixelSize = 2_048
    /// Previews in the import sheet and share extension.
    public static let previewPixelSize = 720

    /// `data` as a JPEG no larger than `maxPixelSize` on its long edge, with
    /// its orientation applied and its metadata (location included) dropped.
    /// Smaller images keep their size. Returns nil if `data` isn't an image.
    public static func prepare(_ data: Data, maxPixelSize: Int = maxPixelSize, quality: Double = 0.8) -> Data? {
        guard let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
              CGImageSourceGetCount(source) > 0,
              let size = pixelSize(of: source) else { return nil }

        // ImageIO's thumbnail is the cheap way to resize; capping it at the
        // image's own size means small images are never scaled up.
        let longEdge = min(maxPixelSize, max(size.width, size.height))
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: longEdge,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }

        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, UTType.jpeg.identifier as CFString, 1, nil) else {
            return nil
        }
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return output as Data
    }

    /// The pixel size of the image in `data`, before any orientation is
    /// applied.
    public static func pixelSize(of data: Data) -> (width: Int, height: Int)? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        return pixelSize(of: source)
    }

    private static func pixelSize(of source: CGImageSource) -> (width: Int, height: Int)? {
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = (properties[kCGImagePropertyPixelWidth] as? NSNumber)?.intValue,
              let height = (properties[kCGImagePropertyPixelHeight] as? NSNumber)?.intValue,
              width > 0, height > 0 else { return nil }
        return (width, height)
    }
}

/// A photo downloaded for an import, ready to preview and save.
public struct ImportedPhoto: Sendable, Equatable, Identifiable {
    /// Where the photo came from.
    public var url: URL
    /// The photo to save: a JPEG at most `RecipePhotoProcessor.maxPixelSize`
    /// on its long edge.
    public var data: Data
    /// A small JPEG for showing the photo before it's saved.
    public var preview: Data

    public var id: URL { url }

    public init(url: URL, data: Data, preview: Data) {
        self.url = url
        self.data = data
        self.preview = preview
    }
}
