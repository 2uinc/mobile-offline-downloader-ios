import Foundation
import WebKit

@MainActor
public class OfflineHTMLDynamicsLinksExtractor: OfflineLinksExtractorProtocol {
    public static var processPool = WKProcessPool() {
        didSet {
            OfflineBackgroundWebview.processPool = processPool
        }
    }

    private var initHtml: String?
    private var initURL: URL?
    private var baseURL: URL?
    private var webview: OfflineBackgroundWebview?
    private var latestData: OfflineBackgroundWebview.OfflineBackgroundWebviewData?
    private var linksHandler: OfflineDownloaderConfig.LinksHandlerBlock?
    
    public var webConfiguration: WKWebViewConfiguration {
        webview?.configuration ?? WKWebViewConfiguration()
    }
    public var html: String? {
        latestData?.html
    }
    public var latestRedirectURL: URL? {
        webview?.latestRedirectURL
    }

    public init(
        html: String,
        baseURL: URL?,
        configuration: WKWebViewConfiguration? = nil,
        linksHandler: OfflineDownloaderConfig.LinksHandlerBlock?
    ) {
        self.initHtml = html
        self.baseURL = baseURL
        self.webview = webviewForConfiguration(configuration)
        self.linksHandler = linksHandler
    }

    public init(
        url: URL,
        configuration: WKWebViewConfiguration? = nil,
        linksHandler: OfflineDownloaderConfig.LinksHandlerBlock?
    ) {
        self.initURL = url
        self.webview = webviewForConfiguration(configuration)
    }

    func webviewForConfiguration(_ configuration: WKWebViewConfiguration?) -> OfflineBackgroundWebview {
        if let configuration = configuration {
            return OfflineBackgroundWebview(
                frame: .zero,
                configuration: configuration
            )
        } else {
            return OfflineBackgroundWebview(
                frame: .zero,
                configuration: {
                    let configuration = WKWebViewConfiguration()
                    configuration.websiteDataStore = WKWebsiteDataStore.nonPersistent()
                    return configuration
                }()
            )
        }
    }
    
    public func fetch() async throws {
        if Task.isCancelled { throw URLError(.cancelled) }
        var data: OfflineBackgroundWebview.OfflineBackgroundWebviewData?
        do {
            data = try await fetchDynamicHTML()
        } catch {
            if error.isOfflineCancel {
                throw error
            }
            throw OfflineHTMLDynamicsLinksExtractorError.cantGetWebviewData(error:error)
        }
        if let data = data {
            latestData = data
        } else {
            throw OfflineHTMLDynamicsLinksExtractorError.cantGetWebviewData(error: nil)
        }
    }

    public func links() async throws -> [OfflineDownloaderLink] {
        guard let data = latestData else { return [] }
        let baseString = baseURL?.absoluteString ?? ""
        let linksExtractor = try OfflineHTMLLinksExtractor(html: data.html, baseURL: baseString)
        do {
            var links = try await linksExtractor.links()
            links.appendDistinct(data.links.map {
                let link = OfflineDownloaderLink(link: $0.fixLink(with: baseString))
                link.extractedLink = linksHandler?(link.link)
                return link
            })
            return links
        } catch {
            if error.isOfflineCancel {
                throw error
            }
            throw OfflineHTMLDynamicsLinksExtractorError.cantGetStorage(error: error)
        }
    }
    
    private func fetchDynamicHTML() async throws -> OfflineBackgroundWebview.OfflineBackgroundWebviewData? {
        if Task.isCancelled { throw URLError(.cancelled) }
        let result: OfflineBackgroundWebview.OfflineBackgroundWebviewData? = try await withTaskCancellationHandler(
            operation: {
                try await withCheckedThrowingContinuation {[weak self] continuation in
                    self?.webview?.didFinishBlock = { data, error in
                        if let error = error {
                            if error.isOfflineCancel {
                                continuation.resume(throwing: error)
                            } else {
                                continuation.resume(
                                    throwing: OfflineHTMLDynamicsLinksExtractorError.cantLoadHTML(
                                        error: error
                                    )
                                )
                            }
                        } else {
                            continuation.resume(returning: data)
                        }
                    }
                    if let url = self?.initURL {
                        let request = URLRequest(url: url)
                        _ = self?.webview?.load(request)
                    } else if let html = self?.initHtml {
                        _ = self?.webview?.loadHTMLString(html, baseURL: self?.baseURL)
                    }
                }
            },
            onCancel: { [weak self] in
                Task { @MainActor [weak self] in
                    self?.stopLoading()
                }
            }
        )
        if Task.isCancelled { throw URLError(.cancelled) }
        return result
    }
    
    public func cookies() async -> [HTTPCookie] {
        await webConfiguration.websiteDataStore.httpCookieStore.allCookies()
    }

    func stopLoading() {
        webview?.stopLoading()
    }
}

extension OfflineHTMLDynamicsLinksExtractor {
    enum OfflineHTMLDynamicsLinksExtractorError: Error, LocalizedError {
        case cantGetWebviewData(error: Error?)
        case cantGetStorage(error: Error)
        case cantLoadHTML(error: Error)

        var errorDescription: String? {
            switch self {
            case .cantGetStorage(let error):
                return "Can't parse html. Error: \(error)"
            case .cantGetWebviewData(let error):
                if let error = error {
                    return "Can't prepare download data. Error: \(error)"
                } else {
                    return "Can't prepare download data."
                }
            case .cantLoadHTML(let error):
                return "Can't load html. Error: \(error)"
            }
        }
    }
}
