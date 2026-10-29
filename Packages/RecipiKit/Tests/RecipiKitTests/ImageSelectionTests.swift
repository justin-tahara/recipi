import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import RecipiKit

struct ImageSelectionTests {
    @Test(arguments: [
        ("image-object-array", [
            "https://cdn.example.com/salmon/4x3-1600.jpg",
            "https://cdn.example.com/salmon/16x9-1280.jpg",
            "https://cdn.example.com/salmon/og-1200x630.jpg",
            "https://cdn.example.com/salmon/twitter-800x418.jpg",
            "https://cdn.example.com/salmon/1x1-300.jpg",
        ]),
        ("tasty-recipes", [
            "https://example.net/wp-content/uploads/cookies.jpg",
            "https://example.net/wp-content/uploads/cookies-og.jpg",
            "https://example.net/wp-content/uploads/cookies-320x180.jpg",
            "https://example.net/wp-content/uploads/cookies-260x195.jpg",
            "https://example.net/wp-content/uploads/cookies-225x225.jpg",
        ]),
        ("wprm-sections", [
            "https://example.org/wp-content/uploads/enchiladas.jpg",
            "https://example.org/wp-content/uploads/enchiladas-500x500.jpg",
            "https://example.org/wp-content/uploads/enchiladas-500x375.jpg",
            "https://example.org/wp-content/uploads/enchiladas-480x270.jpg",
            "https://example.org/wp-content/uploads/enchiladas-1200x630.jpg",
        ]),
        ("yoast-graph", [
            "https://example.com/wp-content/uploads/2024/03/lemon-ricotta-pancakes.jpg",
            "https://example.com/wp-content/uploads/2024/03/lemon-ricotta-pancakes-og.jpg",
            "https://example.com/wp-content/uploads/2024/03/lemon-ricotta-pancakes-twitter.jpg",
        ]),
        ("dotdash-array-type", [
            "https://www.example.com/thmb/classic-beef-chili-4x3.jpg",
            "https://www.example.com/thmb/chili-og=1200x630.jpg",
        ]),
        ("microdata-only", [
            "https://example.com/images/biscuits-large.jpg",
            "https://example.com/og/generic-site-image.png",
        ]),
        ("wprm-html-only", [
            "https://example.com/wp-content/uploads/apple-pie.jpg",
        ]),
        ("lang-de", [
            "https://example.de/bilder/kaesespaetzle.jpg",
            "https://example.de/bilder/kaesespaetzle-og.jpg",
        ]),
    ])
    func ordersTheCandidatesOfAFixture(file: String, expected: [String]) throws {
        let draft = try RecipeImporter.parse(html: Fixture.html(file), sourceURL: Fixture.pageURL(file))
        #expect(draft.imageCandidates.map(\.absoluteString) == expected)
        #expect(draft.imageURL?.absoluteString == expected.first)
    }

    @Test func everyRecipeFixtureHasAPhoto() throws {
        for expectation in FixtureExpectation.all {
            let draft = try RecipeImporter.parse(html: Fixture.html(expectation.file), sourceURL: Fixture.pageURL(expectation.file))
            #expect(!draft.imageCandidates.isEmpty, "No photo for \(expectation.file)")
            #expect(draft.imageCandidates.count <= ImageSelection.maxCandidates)
        }
    }

    @Test func prefersTheLargestStatedSizeOverPageOrder() {
        let base = URL(string: "https://example.com/")!
        let quantity: [String: Any] = ["@type": "QuantitativeValue", "value": 1200]
        let image: [Any] = [
            ["@type": "ImageObject", "url": "small.jpg", "width": 600, "height": 400] as [String: Any],
            ["@type": "ImageObject", "url": "large.jpg", "width": "2400", "height": "1600"] as [String: Any],
            ["@type": "ImageObject", "url": "medium.jpg", "width": quantity, "height": 800] as [String: Any],
        ]
        let candidates = ImageSelection.recipeImages(image, relativeTo: base)
        #expect(ImageSelection.ranked(candidates).map(\.lastPathComponent) == ["large.jpg", "medium.jpg", "small.jpg"])
    }

    @Test func fallsBackToOpenGraphThenTwitter() {
        let html = """
        <meta name="twitter:image" content="https://example.com/twitter.jpg">
        <meta property="og:image" content="https://example.com/og.jpg">
        """
        let candidates = ImageSelection.pageImages(in: html, relativeTo: nil)
        #expect(ImageSelection.ranked(candidates).map(\.lastPathComponent) == ["og.jpg", "twitter.jpg"])
    }

    @Test func dropsDuplicatesAndNonWebAddresses() {
        let base = URL(string: "https://example.com/recipe/")!
        let candidates = ImageSelection.recipeImages(["/a.jpg", "https://example.com/a.jpg", "data:image/png;base64,AAAA", ""], relativeTo: base)
        #expect(ImageSelection.ranked(candidates).map(\.absoluteString) == ["https://example.com/a.jpg"])
    }

    @Test func readsSizesFromResizedFileNames() {
        let size = ImageSelection.sizeInFileName(URL(string: "https://example.com/uploads/pie-1200x800.jpg")!)
        #expect(size?.width == 1_200)
        #expect(size?.height == 800)
        #expect(ImageSelection.sizeInFileName(URL(string: "https://example.com/uploads/pie.jpg")!) == nil)
        #expect(ImageSelection.sizeInFileName(URL(string: "https://example.com/4x3-1600.jpg")!) == nil)
    }
}

struct RecipePhotoProcessorTests {
    @Test(arguments: [(3_000, 1_500), (1_500, 4_000), (2_049, 2_049)])
    func shrinksLargePhotosToTheLimit(width: Int, height: Int) throws {
        let original = try makeImage(width: width, height: height)
        let prepared = try #require(RecipePhotoProcessor.prepare(original))
        let size = try #require(RecipePhotoProcessor.pixelSize(of: prepared))
        #expect(max(size.width, size.height) == RecipePhotoProcessor.maxPixelSize)
        // The aspect ratio survives, give or take rounding.
        let ratio = Double(width) / Double(height)
        #expect(abs(Double(size.width) / Double(size.height) - ratio) < 0.01)
        #expect(isJPEG(prepared))
    }

    @Test func keepsSmallPhotosAtTheirSize() throws {
        let original = try makeImage(width: 800, height: 600)
        let prepared = try #require(RecipePhotoProcessor.prepare(original))
        let size = try #require(RecipePhotoProcessor.pixelSize(of: prepared))
        #expect(size.width == 800)
        #expect(size.height == 600)
        #expect(isJPEG(prepared))
    }

    @Test func makesSmallPreviews() throws {
        let original = try makeImage(width: 3_000, height: 2_000)
        let preview = try #require(RecipePhotoProcessor.prepare(original, maxPixelSize: RecipePhotoProcessor.previewPixelSize))
        let size = try #require(RecipePhotoProcessor.pixelSize(of: preview))
        #expect(max(size.width, size.height) == RecipePhotoProcessor.previewPixelSize)
    }

    @Test func rejectsDataThatIsNotAnImage() {
        #expect(RecipePhotoProcessor.prepare(Data("<html>Not found</html>".utf8)) == nil)
        #expect(RecipePhotoProcessor.prepare(Data()) == nil)
    }

    @Test func fetchesAndShrinksAPhoto() async throws {
        let url = URL(string: "https://photo.fixture.test/big.png")!
        let session = FixtureURLProtocol.session([
            url: FixtureURLProtocol.Route(body: try makeImage(width: 4_000, height: 3_000), contentType: "image/png"),
        ])
        let photo = try #require(await RecipeImporter(session: session).fetchPhoto(at: url))
        let saved = try #require(RecipePhotoProcessor.pixelSize(of: photo.data))
        let preview = try #require(RecipePhotoProcessor.pixelSize(of: photo.preview))
        #expect(max(saved.width, saved.height) == 2_048)
        #expect(max(preview.width, preview.height) == RecipePhotoProcessor.previewPixelSize)
    }

    @Test func skipsAPhotoThatWontLoadAndUsesTheNext() async throws {
        let missing = URL(string: "https://photo.fixture.test/missing.jpg")!
        let notAnImage = URL(string: "https://photo.fixture.test/error-page.jpg")!
        let good = URL(string: "https://photo.fixture.test/good.png")!
        let session = FixtureURLProtocol.session([
            missing: FixtureURLProtocol.Route(status: 404),
            notAnImage: .html("<html>Oops</html>"),
            good: FixtureURLProtocol.Route(body: try makeImage(width: 1_000, height: 500), contentType: "image/png"),
        ])
        var draft = RecipeDraft(title: "Soup")
        draft.imageCandidates = [missing, notAnImage, good]
        draft.imageURL = missing
        let data = try #require(await RecipeImporter(session: session).fetchImage(for: draft))
        #expect(RecipePhotoProcessor.pixelSize(of: data)?.width == 1_000)
    }

    /// A PNG of a colored gradient, drawn in memory.
    private func makeImage(width: Int, height: Int) throws -> Data {
        let context = try #require(CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.setFillColor(CGColor(red: 0.85, green: 0.42, blue: 0.23, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.setFillColor(CGColor(red: 0.2, green: 0.5, blue: 0.3, alpha: 1))
        context.fillEllipse(in: CGRect(x: width / 4, y: height / 4, width: width / 2, height: height / 2))
        let image = try #require(context.makeImage())
        let data = NSMutableData()
        let destination = try #require(CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        #expect(CGImageDestinationFinalize(destination))
        return data as Data
    }

    private func isJPEG(_ data: Data) -> Bool {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let type = CGImageSourceGetType(source) else { return false }
        return (type as String) == UTType.jpeg.identifier
    }
}

@MainActor
struct ImportPhotoChoiceTests {
    @Test func picksTheFirstPhotoThatLoadsAndDropsRepeats() async throws {
        let png = try makeTinyPNG()
        let broken = URL(string: "https://choice.fixture.test/broken.jpg")!
        let first = URL(string: "https://choice.fixture.test/first.png")!
        let copy = URL(string: "https://choice.fixture.test/first-copy.png")!
        let session = FixtureURLProtocol.session([
            broken: FixtureURLProtocol.Route(status: 500),
            first: FixtureURLProtocol.Route(body: png, contentType: "image/png"),
            copy: FixtureURLProtocol.Route(body: png, contentType: "image/png"),
        ])
        var draft = RecipeDraft(title: "Soup")
        draft.imageCandidates = [broken, first, copy]
        let choice = ImportPhotoChoice(draft: draft, importer: RecipeImporter(session: session))
        #expect(choice.isLoadingFirstPhoto)
        await choice.load()
        #expect(!choice.isLoading)
        #expect(choice.photos.map(\.url) == [first])
        #expect(choice.selected?.url == first)

        choice.selectedURL = nil
        #expect(choice.selected == nil)
    }

    @Test func endsUpWithNoPhotoWhenNoneLoad() async {
        var draft = RecipeDraft(title: "Soup")
        draft.imageCandidates = [URL(string: "https://choice.fixture.test/nothing-here.jpg")!]
        let choice = ImportPhotoChoice(draft: draft, importer: RecipeImporter(session: FixtureURLProtocol.session([:])))
        await choice.load()
        #expect(choice.photos.isEmpty)
        #expect(choice.selected == nil)
        #expect(!choice.isLoadingFirstPhoto)
    }

    private func makeTinyPNG() throws -> Data {
        let context = try #require(CGContext(
            data: nil, width: 40, height: 30, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.setFillColor(CGColor(red: 0.3, green: 0.4, blue: 0.9, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 40, height: 30))
        let image = try #require(context.makeImage())
        let data = NSMutableData()
        let destination = try #require(CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        _ = CGImageDestinationFinalize(destination)
        return data as Data
    }
}
