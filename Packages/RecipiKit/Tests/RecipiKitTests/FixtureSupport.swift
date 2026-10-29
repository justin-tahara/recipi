import Foundation
import Testing

/// Loads the hand-written pages in `Fixtures/`. Each reproduces a markup
/// pattern real recipe sites use; see the comment at the top of each file.
enum Fixture {
    static func html(_ name: String) throws -> String {
        let url = try #require(
            Bundle.module.url(forResource: name, withExtension: "html", subdirectory: "Fixtures"),
            "Missing fixture \(name).html"
        )
        return try String(contentsOf: url, encoding: .utf8)
    }

    /// The address a fixture is parsed as if it were served from.
    static func pageURL(_ name: String) -> URL {
        URL(string: "https://example.com/recipes/\(name)/")!
    }
}

/// Serves canned responses to a `URLSession`, so the importer's fetching
/// (redirects, meta refreshes, AMP pages) can be tested without a network.
/// Tests register routes under their own made-up hosts so they can run in
/// parallel.
final class FixtureURLProtocol: URLProtocol {
    struct Route: Sendable {
        var body: Data = Data()
        var status: Int = 200
        var contentType: String = "text/html; charset=utf-8"
        var redirect: URL?
        /// A `URLError` code to fail with instead of answering.
        var failure: Int?

        static func html(_ html: String, status: Int = 200) -> Route {
            Route(body: Data(html.utf8), status: status)
        }

        static func redirect(to url: URL, status: Int = 301) -> Route {
            Route(status: status, redirect: url)
        }

        static func failing(_ code: URLError.Code) -> Route {
            Route(failure: code.rawValue)
        }
    }

    private static let lock = NSLock()
    nonisolated(unsafe) private static var routes: [URL: Route] = [:]
    nonisolated(unsafe) private static var requestHeaders: [URL: [String: String]] = [:]

    /// The headers of the last request made for `url`.
    static func headers(sentTo url: URL) -> [String: String]? {
        lock.withLock { requestHeaders[url] }
    }

    /// A session that answers from `routes` and fails anything else.
    static func session(_ newRoutes: [URL: Route]) -> URLSession {
        lock.withLock { routes.merge(newRoutes) { _, new in new } }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [FixtureURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url,
              let route = Self.lock.withLock({ Self.routes[url] }) else {
            client?.urlProtocol(self, didFailWithError: URLError(.cannotFindHost))
            return
        }
        let headers = request.allHTTPHeaderFields ?? [:]
        Self.lock.withLock { Self.requestHeaders[url] = headers }
        if let failure = route.failure {
            client?.urlProtocol(self, didFailWithError: URLError(URLError.Code(rawValue: failure)))
            return
        }
        var responseHeaders = ["Content-Type": route.contentType]
        if let redirect = route.redirect { responseHeaders["Location"] = redirect.absoluteString }
        let response = HTTPURLResponse(url: url, statusCode: route.status, httpVersion: "HTTP/1.1", headerFields: responseHeaders)!
        if let redirect = route.redirect {
            client?.urlProtocol(self, wasRedirectedTo: URLRequest(url: redirect), redirectResponse: response)
            return
        }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: route.body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
