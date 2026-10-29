import Foundation

/// A photo a page offers for its recipe, with its size when the page gives
/// it or the file name shows it.
struct ImageCandidate: Equatable {
    enum Source {
        /// The recipe's own `image` (JSON-LD or microdata).
        case recipe
        case openGraph
        case twitter
    }

    var url: URL
    var source: Source
    var width: Int?
    var height: Int?
    /// Whether the page stated the size, rather than us reading it from a
    /// file name like `photo-1200x800.jpg`.
    var sizeIsStated = false

    var area: Int? {
        guard let width, let height else { return nil }
        return width * height
    }

    var longEdge: Int? {
        guard let width, let height else { return nil }
        return max(width, height)
    }
}

/// Picks the best photo for an imported recipe and orders the rest.
enum ImageSelection {
    /// At most this many candidates are kept on the draft.
    static let maxCandidates = 8
    /// Images known to be smaller than this on their long edge (thumbnails,
    /// square crops for rich results) go to the back of the list.
    static let smallLongEdge = 400

    /// The candidates in a recipe's `image` value: a URL, an `ImageObject`
    /// with optional `width` and `height`, or an array of either.
    static func recipeImages(_ value: Any?, relativeTo base: URL?) -> [ImageCandidate] {
        switch value {
        case let string as String:
            return candidate(string, source: .recipe, relativeTo: base).map { [$0] } ?? []
        case let array as [Any]:
            return array.flatMap { recipeImages($0, relativeTo: base) }
        case let object as [String: Any]:
            let address = object["url"] ?? object["contentUrl"]
            if let addresses = address as? [Any] {
                return recipeImages(addresses, relativeTo: base)
            }
            guard let string = address as? String,
                  var found = candidate(string, source: .recipe, relativeTo: base) else { return [] }
            if let width = pixels(object["width"]), let height = pixels(object["height"]) {
                found.width = width
                found.height = height
                found.sizeIsStated = true
            }
            return [found]
        default:
            return []
        }
    }

    /// `og:image` and `twitter:image` from the page's meta tags.
    static func pageImages(in html: String, relativeTo base: URL?) -> [ImageCandidate] {
        let tags: [(String, ImageCandidate.Source)] = [
            ("og:image", .openGraph), ("og:image:secure_url", .openGraph), ("og:image:url", .openGraph),
            ("twitter:image", .twitter), ("twitter:image:src", .twitter),
        ]
        return tags.compactMap { key, source in
            HTMLText.metaContent(key, in: html).flatMap { candidate($0, source: source, relativeTo: base) }
        }
    }

    static func candidate(_ string: String, source: ImageCandidate.Source, relativeTo base: URL?) -> ImageCandidate? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let url = URL(string: trimmed, relativeTo: base)?.absoluteURL,
              let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" else { return nil }
        var found = ImageCandidate(url: url, source: source)
        if let size = sizeInFileName(url) {
            found.width = size.width
            found.height = size.height
        }
        return found
    }

    /// The size WordPress and similar CMSs put in resized file names, e.g.
    /// `cookies-320x180.jpg`.
    static func sizeInFileName(_ url: URL) -> (width: Int, height: Int)? {
        let name = url.lastPathComponent
        guard let match = name.range(of: #"-(\d{2,5})x(\d{2,5})\.[A-Za-z0-9]{3,4}$"#, options: .regularExpression) else {
            return nil
        }
        let parts = name[match].dropFirst().split(separator: ".")[0].split(separator: "x")
        guard parts.count == 2, let width = Int(parts[0]), let height = Int(parts[1]) else { return nil }
        return (width, height)
    }

    private static func pixels(_ value: Any?) -> Int? {
        switch value {
        case let number as NSNumber: return number.intValue > 0 ? number.intValue : nil
        case let string as String: return Int(string.filter(\.isNumber)).flatMap { $0 > 0 ? $0 : nil }
        case let object as [String: Any]: return pixels(object["value"])
        default: return nil
        }
    }

    /// The candidates' URLs, best first:
    /// 1. recipe images with a stated size, largest first;
    /// 2. other recipe images, in page order, with the full-size original
    ///    ahead of resized copies (largest copy first);
    /// 3. `og:image`, then `twitter:image`;
    /// 4. anything known to be small, largest first.
    static func ranked(_ candidates: [ImageCandidate]) -> [URL] {
        var seen = Set<URL>()
        let unique = candidates.enumerated().filter { seen.insert($0.element.url).inserted }

        func isSmall(_ candidate: ImageCandidate) -> Bool {
            (candidate.longEdge ?? .max) < smallLongEdge
        }
        func largestFirst(_ items: [(offset: Int, element: ImageCandidate)]) -> [ImageCandidate] {
            items.sorted { lhs, rhs in
                let left = lhs.element.area ?? 0, right = rhs.element.area ?? 0
                return left != right ? left > right : lhs.offset < rhs.offset
            }.map(\.element)
        }

        let recipe = unique.filter { $0.element.source == .recipe && !isSmall($0.element) }
        let stated = largestFirst(recipe.filter { $0.element.sizeIsStated })
        let originals = recipe.filter { !$0.element.sizeIsStated && $0.element.area == nil }.map(\.element)
        let resized = largestFirst(recipe.filter { !$0.element.sizeIsStated && $0.element.area != nil })
        let openGraph = unique.filter { $0.element.source == .openGraph && !isSmall($0.element) }.map(\.element)
        let twitter = unique.filter { $0.element.source == .twitter && !isSmall($0.element) }.map(\.element)
        let small = largestFirst(unique.filter { isSmall($0.element) })

        let ordered = stated + originals + resized + openGraph + twitter + small
        return ordered.prefix(maxCandidates).map(\.url)
    }
}
