import Foundation
import WebKit

@MainActor
class OfflineHTMLDynamicsLinksExtractor: OfflineLinksExtractorProtocol {
    private var initHtml: String?
    private var initURL: URL?
    private var baseURL: URL?
    private var webview: OfflineBackgroundWebview?
    var webConfiguration: WKWebViewConfiguration {
        webview?.configuration ?? WKWebViewConfiguration()
    }
    var html: String?

    init(html: String, baseURL: URL?, configuration: WKWebViewConfiguration? = nil) {
        self.initHtml = html
        self.baseURL = baseURL
        self.webview = webviewForConfiguration(configuration)
    }

    init(url: URL, configuration: WKWebViewConfiguration? = nil) {
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

    func links() async throws -> [OfflineDownloaderLink] {
        if Task.isCancelled { throw URLError(.cancelled) }
        if let data = try await fetchDynamicHTML() {
            html = data.html
            let baseString = baseURL?.absoluteString ?? ""
            let linksExtractor = try OfflineHTMLLinksExtractor(html: data.html, baseURL: baseString)
            do {
                var links = try await linksExtractor.links()
                links.appendDistinct(data.links.map {
                    OfflineDownloaderLink(link: $0.fixLink(with: baseString))
                })
                return links
            } catch {
                if error.isCancelled {
                    throw error
                }
                throw OfflineHTMLDynamicsLinksExtractorError.cantGetStorage(error: error)
            }
        } else {
            throw OfflineHTMLDynamicsLinksExtractorError.cantGetWebviewData
        }
    }
    
    func fetchDynamicHTML() async throws -> OfflineBackgroundWebview.OfflineBackgroundWebviewData? {
        if Task.isCancelled { throw URLError(.cancelled) }
        let result: OfflineBackgroundWebview.OfflineBackgroundWebviewData? = try await withTaskCancellationHandler(
            operation: {
                try await withCheckedThrowingContinuation {[weak webview] continuation in
                    webview?.didFinishBlock = { data, error in
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
                    if let url = initURL {
                        let request = URLRequest(url: url)
                        _ = webview?.load(request)
                    } else if let html = initHtml {
                        _ = webview?.loadHTMLString(html, baseURL: baseURL)
                    }
                }
            },
            onCancel: {
                Task { @MainActor in
                    stopLoading()
                }
            }
        )
        if Task.isCancelled { throw URLError(.cancelled) }
        return result
    }

    func stopLoading() {
        webview?.stopLoading()
    }
}

extension OfflineHTMLDynamicsLinksExtractor {
    enum OfflineHTMLDynamicsLinksExtractorError: Error, LocalizedError {
        case cantGetWebviewData
        case cantGetStorage(error: Error)
        case cantLoadHTML(error: Error)

        var errorDescription: String? {
            switch self {
            case .cantGetStorage(let error):
                return "Can't parse html. Error: \(error)"
            case .cantGetWebviewData:
                return "Can't prepare download data"
            case .cantLoadHTML(let error):
                return "Can't load html. Error: \(error)"
            }
        }
    }
}
