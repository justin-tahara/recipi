import Foundation
import Testing
@testable import RecipiKit

/// What the importer says when the page isn't a recipe page it can read:
/// error statuses, bot checks, files, empty pages and network failures each
/// get their own error instead of "No recipe was found". Responses come
/// from `FixtureURLProtocol`, never the network.
struct ImportFailureTests {
    private func importer(_ routes: [URL: FixtureURLProtocol.Route]) -> RecipeImporter {
        RecipeImporter(session: FixtureURLProtocol.session(routes), rendersJavaScript: false)
    }

    /// Imports `url` expecting it to fail, and returns the error and trace.
    private func failure(importing url: URL, from routes: [URL: FixtureURLProtocol.Route]) async -> (error: RecipeImportError?, trace: ImportTrace) {
        var trace = ImportTrace()
        do {
            _ = try await importer(routes).importRecipe(from: url, trace: &trace)
            return (nil, trace)
        } catch {
            return (error as? RecipeImportError, trace)
        }
    }

    /// A Cloudflare "Just a moment" page, trimmed. The refresh has no
    /// target, so it isn't followed.
    private static let cloudflareChallenge = """
    <!DOCTYPE html><html lang="en-US"><head><title>Just a moment...</title>
    <meta http-equiv="refresh" content="390"></head>
    <body><div class="main-wrapper"><h1>example.com</h1>
    <p>Verifying you are human. This may take a few seconds.</p></div>
    <script>window._cf_chl_opt={cvId:'3',cZone:'example.com',cType:'managed'};</script>
    </body></html>
    """

    // MARK: - Status codes

    @Test func aForbiddenPageIsBlocked() async throws {
        let url = URL(string: "https://forbidden.fixture.test/recipes/stew/")!
        let (error, trace) = await failure(importing: url, from: [url: .html("<html><body><h1>403 Forbidden</h1></body></html>", status: 403)])
        #expect(error == .blockedBySite)
        #expect(trace.reason == "HTTP 403")
        #expect(trace.fetches.map(\.status) == [403])
    }

    @Test func tooManyRequestsIsBlocked() async {
        let url = URL(string: "https://ratelimit.fixture.test/recipes/stew/")!
        await #expect(throws: RecipeImportError.blockedBySite) {
            try await importer([url: .html("Too Many Requests", status: 429)]).importRecipe(from: url)
        }
    }

    @Test func aChallengePageServedWithStatus200IsBlocked() async throws {
        let url = URL(string: "https://challenge.fixture.test/recipes/stew/")!
        let (error, trace) = await failure(importing: url, from: [url: .html(Self.cloudflareChallenge)])
        #expect(error == .blockedBySite)
        #expect(trace.reason == "Cloudflare challenge")
    }

    @Test func aChallengePageServedWith503IsBlockedNotASiteError() async {
        let url = URL(string: "https://challenge503.fixture.test/recipes/stew/")!
        await #expect(throws: RecipeImportError.blockedBySite) {
            try await importer([url: .html(Self.cloudflareChallenge, status: 503)]).importRecipe(from: url)
        }
    }

    @Test func aPlainServerErrorIsASiteError() async {
        let url = URL(string: "https://broken.fixture.test/recipes/stew/")!
        await #expect(throws: RecipeImportError.siteUnavailable) {
            try await importer([url: .html("<h1>Internal Server Error</h1>", status: 500)]).importRecipe(from: url)
        }
    }

    @Test(arguments: [404, 410])
    func aMissingPageIsNotFound(status: Int) async {
        let url = URL(string: "https://missing\(status).fixture.test/recipes/stew/")!
        let page = "<html><head><title>Page not found</title></head><body><p>Sorry, that page is gone.</p></body></html>"
        await #expect(throws: RecipeImportError.pageNotFound) {
            try await importer([url: .html(page, status: status)]).importRecipe(from: url)
        }
    }

    @Test func aRecipeOnAnErrorStatusPageStillImports() async throws {
        // Seen in the wild: a page served with the wrong status. If the
        // recipe is there, it's the recipe.
        let url = URL(string: "https://wrongstatus.fixture.test/recipes/soup/")!
        let draft = try await importer([url: .html(try Fixture.html("yield-range-string-image"), status: 404)]).importRecipe(from: url)
        #expect(draft.title == "Roasted Tomato Soup")
    }

    // MARK: - Not a page

    @Test func aPDFIsNotAWebPage() async throws {
        let url = URL(string: "https://files.fixture.test/cookbook.pdf")!
        var route = FixtureURLProtocol.Route(body: Data("%PDF-1.7\n%âãÏÓ\n".utf8))
        route.contentType = "application/pdf"
        let (error, trace) = await failure(importing: url, from: [url: route])
        #expect(error == .notAWebPage)
        #expect(trace.reason == "content type application/pdf")
    }

    @Test func aPhotoIsNotAWebPage() async {
        let url = URL(string: "https://files.fixture.test/soup.jpg")!
        var route = FixtureURLProtocol.Route(body: Data([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10]))
        route.contentType = "image/jpeg"
        await #expect(throws: RecipeImportError.notAWebPage) {
            try await importer([url: route]).importRecipe(from: url)
        }
    }

    @Test func aPDFWithAVagueContentTypeIsNotAWebPage() async {
        let url = URL(string: "https://files.fixture.test/download?id=7")!
        var route = FixtureURLProtocol.Route(body: Data("%PDF-1.4\n".utf8))
        route.contentType = "application/octet-stream"
        await #expect(throws: RecipeImportError.notAWebPage) {
            try await importer([url: route]).importRecipe(from: url)
        }
    }

    @Test func anEmptyPageIsBlocked() async throws {
        let url = URL(string: "https://empty.fixture.test/recipes/stew/")!
        let (error, trace) = await failure(importing: url, from: [url: .html("")])
        #expect(error == .blockedBySite)
        #expect(trace.reason == "empty page")
        #expect(trace.fetches.map(\.byteCount) == [0])
    }

    @Test func anOrdinaryPageWithACaptchaOnItsCommentFormHasNoRecipe() async {
        // A long page that merely mentions a captcha is not a bot check.
        let url = URL(string: "https://blog.fixture.test/about/")!
        let paragraph = "<p>We cook every weekend and write about what worked and what didn't, with notes on every substitution.</p>\n"
        let page = """
        <html><head><title>About us</title></head><body>
        \(String(repeating: paragraph, count: 30))
        <form id="comments"><div class="g-recaptcha" data-sitekey="abc"></div></form>
        <script src="https://www.google.com/recaptcha/api.js"></script>
        </body></html>
        """
        await #expect(throws: RecipeImportError.noRecipeFound) {
            try await importer([url: .html(page)]).importRecipe(from: url)
        }
    }

    // MARK: - Redirects

    @Test func followsARedirectChainAndSavesTheLinkWithoutTracking() async throws {
        let short = URL(string: "https://chain.fixture.test/s/1")!
        let middle = URL(string: "https://chain.fixture.test/go/soup")!
        let page = URL(string: "https://chain.fixture.test/recipes/soup/?utm_source=newsletter&utm_medium=email&serving=4")!
        let importer = importer([
            short: .redirect(to: middle, status: 301),
            middle: .redirect(to: page, status: 302),
            page: .html(try Fixture.html("yield-range-string-image")),
        ])
        var trace = ImportTrace()
        let draft = try await importer.importRecipe(from: short, trace: &trace)
        #expect(draft.title == "Roasted Tomato Soup")
        #expect(draft.sourceURL == URL(string: "https://chain.fixture.test/recipes/soup/?serving=4"))
        // URLSession follows the redirects within one fetch.
        #expect(trace.fetches.count == 1)
        #expect(trace.fetches.first?.finalURL == page)
        #expect(trace.fetches.first?.status == 200)
    }

    @Test func aRedirectToAMissingPageIsNotFound() async {
        let short = URL(string: "https://chain404.fixture.test/s/1")!
        let gone = URL(string: "https://chain404.fixture.test/recipes/gone/")!
        let importer = importer([short: .redirect(to: gone), gone: .html("Not found", status: 404)])
        await #expect(throws: RecipeImportError.pageNotFound) {
            try await importer.importRecipe(from: short)
        }
    }

    @Test func upgradesPlainHTTP() throws {
        let plain = try #require(URL(string: "http://example.com/pie?x=1"))
        let secure = try #require(URL(string: "https://example.com/pie"))
        #expect(RecipeImporter.upgradingToHTTPS(plain).absoluteString == "https://example.com/pie?x=1")
        #expect(RecipeImporter.upgradingToHTTPS(secure) == secure)
    }

    @Test func asksForTheHTTPSPage() async throws {
        let page = URL(string: "https://upgrade.fixture.test/recipes/soup/")!
        let importer = importer([page: .html(try Fixture.html("yield-range-string-image"))])
        let draft = try await importer.importRecipe(from: URL(string: "http://upgrade.fixture.test/recipes/soup/")!)
        #expect(draft.sourceURL == page)
    }

    @Test func importsThePageBehindAGoogleAMPLink() async throws {
        let page = URL(string: "https://ampviewer.fixture.test/recipes/soup/")!
        let importer = importer([page: .html(try Fixture.html("yield-range-string-image"))])
        let draft = try await importer.importRecipe(from: URL(string: "https://www.google.com/amp/s/ampviewer.fixture.test/recipes/soup/")!)
        #expect(draft.sourceURL == page)
    }

    @Test func followsAnAppleNewsLinkToThePublishersPage() async throws {
        let news = URL(string: "https://apple.news/AFixtureStory1")!
        let page = URL(string: "https://publisher.fixture.test/recipes/soup/")!
        let newsPage = """
        <html><head><title>Roasted Tomato Soup</title></head><body>
        <a class="click-here" href="https://apps.apple.com/app/apple-news/id1066498020">Open in News</a>
        <script>redirectToUrlAfterTimeout("https:\\/\\/publisher.fixture.test\\/recipes\\/soup\\/", 0);</script>
        </body></html>
        """
        let importer = importer([news: .html(newsPage), page: .html(try Fixture.html("yield-range-string-image"))])
        let draft = try await importer.importRecipe(from: news)
        #expect(draft.title == "Roasted Tomato Soup")
        #expect(draft.sourceURL == page)
    }

    // MARK: - Network

    @Test func offlineSaysSo() async {
        let url = URL(string: "https://offline.fixture.test/recipes/stew/")!
        await #expect(throws: RecipeImportError.offline) {
            try await importer([url: .failing(.notConnectedToInternet)]).importRecipe(from: url)
        }
    }

    @Test func aTimeoutSaysSo() async {
        let url = URL(string: "https://slow.fixture.test/recipes/stew/")!
        await #expect(throws: RecipeImportError.timedOut) {
            try await importer([url: .failing(.timedOut)]).importRecipe(from: url)
        }
    }

    @Test func anUnknownHostIsUnreachable() async throws {
        // The fixture session fails unknown links with "cannot find host".
        let url = URL(string: "https://nowhere.fixture.test/recipes/stew/")!
        let (error, trace) = await failure(importing: url, from: [:])
        #expect(error == .siteUnreachable)
        #expect(trace.networkError != nil)
        #expect(trace.fetches.isEmpty)
    }

    // MARK: - The request

    @Test func asksLikeSafariOnAnIPhone() async throws {
        let url = URL(string: "https://headers.fixture.test/recipes/soup/")!
        _ = try await importer([url: .html(try Fixture.html("yield-range-string-image"))]).importRecipe(from: url)
        let headers = try #require(FixtureURLProtocol.headers(sentTo: url))
        #expect(headers["User-Agent"]?.contains("iPhone") == true)
        #expect(headers["User-Agent"]?.contains("Safari/") == true)
        #expect(headers["Accept"]?.hasPrefix("text/html") == true)
        #expect(headers["Accept-Language"]?.isEmpty == false)
    }

    @Test(arguments: [
        (["en-GB", "de"], "en-GB,en;q=0.9,de;q=0.8"),
        (["en-US", "en"], "en-US,en;q=0.9"),
        (["pt_BR"], "pt-BR,pt;q=0.9"),
        (["zh-Hans-CN", "ja-JP"], "zh-Hans-CN,zh;q=0.9,ja-JP;q=0.8,ja;q=0.7"),
        ([], "en-US,en;q=0.9"),
    ])
    func buildsAcceptLanguage(languages: [String], expected: String) {
        #expect(RecipeImporter.acceptLanguage(for: languages) == expected)
    }

    // MARK: - Telling bot checks from pages

    @Test(arguments: [
        (#"<html><head><title>Just a moment...</title></head><body></body></html>"#, "Cloudflare challenge"),
        (#"<html><body><script src="https://ct.captcha-delivery.com/c.js"></script></body></html>"#, "DataDome challenge"),
        (#"<html><body><div id="px-captcha"></div></body></html>"#, "PerimeterX challenge"),
        ("<HTML><HEAD><TITLE>Access Denied</TITLE></HEAD><BODY>You don't have permission to access this server.</BODY></HTML>", "access denied"),
    ])
    func recognisesBotChecks(html: String, expected: String) {
        #expect(PageCheck.challengeMarker(in: html) == expected)
    }

    @Test func aRecipePageIsNotABotCheck() throws {
        #expect(PageCheck.challengeMarker(in: try Fixture.html("wprm-sections")) == nil)
        #expect(PageCheck.problem(status: 200, html: try Fixture.html("js-rendered-only")) == nil)
    }
}

/// The nightly live check's report, without the network: sites that turned
/// the runner away are warnings, and only parser failures fail the run.
struct LiveImportReportTests {
    private static func fetch(_ link: String, status: Int, bytes: Int) -> ImportTrace.Fetch {
        let url = URL(string: link)!
        return ImportTrace.Fetch(requestedURL: url, finalURL: url, status: status, byteCount: bytes, mimeType: "text/html")
    }

    @Test func classifiesImportErrors() {
        #expect(LiveImportCheck.Outcome(RecipeImportError.blockedBySite) == .blockedBySite)
        #expect(LiveImportCheck.Outcome(RecipeImportError.pageNotFound) == .pageNotFound)
        #expect(LiveImportCheck.Outcome(RecipeImportError.noRecipeFound) == .noRecipeFound)
        #expect(LiveImportCheck.Outcome(RecipeImportError.timedOut) == .networkError)
        #expect(LiveImportCheck.Outcome(URLError(.cannotConnectToHost)) == .networkError)

        #expect(LiveImportCheck.Outcome.noRecipeFound.isFailure)
        #expect(LiveImportCheck.Outcome.incomplete.isFailure)
        #expect(!LiveImportCheck.Outcome.blockedBySite.isFailure)
        #expect(LiveImportCheck.Outcome.blockedBySite.isWarning)
        #expect(!LiveImportCheck.Outcome.pageNotFound.isFailure)
        #expect(!LiveImportCheck.Outcome.parsedAfterRender.isFailure)
    }

    @Test func listsBlockedSitesApartFromFailures() {
        let blocked = LiveImportCheck.SiteResult(
            url: URL(string: "https://blocked.example/pie/")!,
            outcome: .blockedBySite,
            trace: ImportTrace(fetches: [Self.fetch("https://blocked.example/pie/", status: 403, bytes: 5_120)], reason: "HTTP 403, Cloudflare challenge"),
            detail: RecipeImportError.blockedBySite.localizedDescription,
            renderNote: "web view found no recipe either"
        )
        let failed = LiveImportCheck.SiteResult(
            url: URL(string: "https://changed.example/stew/")!,
            outcome: .noRecipeFound,
            trace: ImportTrace(fetches: [Self.fetch("https://changed.example/stew/", status: 200, bytes: 180_000)]),
            detail: RecipeImportError.noRecipeFound.localizedDescription
        )
        let parsed = LiveImportCheck.SiteResult(
            url: URL(string: "https://fine.example/soup/")!,
            outcome: .parsed,
            trace: ImportTrace(fetches: [Self.fetch("https://fine.example/soup/", status: 200, bytes: 90_000)]),
            detail: "Soup | 5 ingredients, 3 steps"
        )
        let report = LiveImportCheck.report([blocked, failed, parsed])
        #expect(report.contains("1 of 3 sites imported, 1 failed and 1 couldn't be checked."))
        #expect(report.contains("### Failures"))
        #expect(report.contains("### Couldn't check (not failures)"))
        #expect(report.contains("| https://blocked.example/pie/ | blocked by site | 403 | same | 5120 |"))
        #expect(report.contains("[HTTP 403, Cloudflare challenge]"))
        // A pipe in a title doesn't break the table.
        #expect(report.contains("Soup \\| 5 ingredients"))
    }
}
