import Foundation
import UIKit

/// Photos people take of what they cooked can be 12 megapixels or more.
/// They're shrunk before saving so the library and iCloud stay small.
enum CookPhoto {
    /// JPEG data with the longer side at most `maxDimension` pixels, or nil
    /// when `data` isn't an image.
    static func prepared(from data: Data, maxDimension: CGFloat = 1600) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        let longest = max(image.size.width, image.size.height)
        guard longest > 0 else { return nil }
        let scale = min(1, maxDimension / longest)
        let size = CGSize(width: (image.size.width * scale).rounded(), height: (image.size.height * scale).rounded())
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let resized = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        return resized.jpegData(compressionQuality: 0.8)
    }
}
