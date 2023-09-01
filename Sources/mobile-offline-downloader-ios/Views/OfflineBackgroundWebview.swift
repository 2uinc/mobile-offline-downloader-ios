import Foundation
import WebKit

class OfflineBackgroundWebview: WKWebView, OfflineHTMLLinksExtractorProtocol {
    struct OfflineBackgroundWebviewData: Codable {
        var html: String
        var links: [String]
    }

    let completionMessage: String = "loadCompleted"
    let completionScheme: String = "completed"
    var didFinishBlock: ((OfflineBackgroundWebviewData?, Error?) -> Void)?
    var latestRedirectURL: URL?
    var isCompletionCalled: Bool = false
    
    static var processPool = WKProcessPool()

    override init(frame: CGRect, configuration: WKWebViewConfiguration) {
        configuration.processPool = OfflineBackgroundWebview.processPool
        super.init(frame: frame, configuration: configuration)
        navigationDelegate = self
        addScript(to: configuration)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override func load(_ request: URLRequest) -> WKNavigation? {
        resetProperties()
        return super.load(request)
    }
    
    override func loadHTMLString(_ string: String, baseURL: URL?) -> WKNavigation? {
        resetProperties()
        return super.loadHTMLString(string, baseURL: baseURL)
    }
    
    private func resetProperties() {
        isCompletionCalled = false
    }

    private func addScript(to configuration: WKWebViewConfiguration) {
        let sources = sourceTags.map { "\"\($0)\"" }.joined(separator: ",")
        let attributes = sourceAttributes.map { "\"\($0)\"" }.joined(separator: ",")
        let formats = documentExtensions.map { "\"\($0)\"" }.joined(separator: ",")
        let source = """
        window.extractedLinks = getLinksForElement(document);
        window.requestLinks = [];
        var origOpen = XMLHttpRequest.prototype.open;
        var requestsCount = 0;
        XMLHttpRequest.prototype.open = function() {
            stopCompletionTimer();
            requestsCount = requestsCount + 1;
            this.addEventListener('load', function() {
                requestsCount = requestsCount - 1;
                if (requestsCount == 0) {
                    startCompletionTimer();
                }

                if (this.responseURL != null && this.responseURL.length > 0) {
                    window.requestLinks.push(this.responseURL);
                }
            });
            this.addEventListener('error', function() {
                requestsCount = requestsCount - 1;
                if (requestsCount == 0) {
                    startCompletionTimer();
                }
            });
            this.addEventListener('abort', function() {
                requestsCount = requestsCount - 1;
                if (requestsCount == 0) {
                    startCompletionTimer();
                }
            });

            origOpen.apply(this, arguments);
        };

        function addObserverForDomChanges() {
            window.observerConfig = {
                childList: true,
                attributes: true,
                subtree: true
            };

            window.domObserver = new MutationObserver(htmlChanged);
            window.domObserver.observe(document, window.observerConfig);
        }

        function htmlChanged(mutationsList, observer) {
            startCompletionTimer();
            for (let mutation of mutationsList) {
                let links = getLinksForElement(mutation.target);
                window.extractedLinks = window.extractedLinks.concat(links);
                window.extractedLinks = window.extractedLinks.filter((v, i, a) => a.indexOf(v) === i);
            }
        }

        function startCompletionTimer() {
            stopCompletionTimer();
            window.timerId = setTimeout( function() {
                window.location = "\(completionScheme)://completionScheme.completionScheme";
            }, 10000);
        }

        function stopCompletionTimer() {
            clearTimeout(window.timerId);
        }

        function canDownload(tag, link) {
            if (tag.nodeName.toLowerCase() == "a") {
                return [\(formats)].includes(link.split('.').pop())
            }

            return true;
        }

        function getLinksForElement(element) {
            var links = [];
            var tags = [];
            for (let source of [\(sources)]) {
                tags = tags.concat(Array.from(element.getElementsByTagName(source)));
            }

            for (let tag of tags) {
                for (let attribute of [\(attributes)]) {
                    let value = tag.getAttribute(attribute);
                    if (value != null && value.length > 0 && canDownload(tag, value)) {
                        links.push(value);
                    }
                }
            }
            return links.filter((v, i, a) => a.indexOf(v) === i);
        }

        addObserverForDomChanges();
        startCompletionTimer();
        """
        let script = WKUserScript(source: source, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        configuration.userContentController.addUserScript(script)
    }
}

extension OfflineBackgroundWebview: WKNavigationDelegate {

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        if !isCompletionCalled {
            isCompletionCalled = true
            didFinishBlock?(nil, error)
        }
    }
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        let request = navigationAction.request
        if request.url?.scheme == completionScheme {
            if !isCompletionCalled {
                webView.evaluateJavaScript(
                    "JSON.stringify({ \"links\": window.extractedLinks, \"html\": document.documentElement.outerHTML })"
                ) { [weak self] result, error in
                    if let result = result as? String, let data = result.data(using: .utf8) {
                        let decoder = JSONDecoder()
                        do {
                            let webviewData = try decoder.decode(OfflineBackgroundWebviewData.self, from: data)
                            self?.didFinishBlock?(webviewData, nil)
                        } catch {
                            self?.didFinishBlock?(nil, error)
                        }
                    } else {
                        self?.didFinishBlock?(nil, error)
                    }
                }
                isCompletionCalled = true
            }
            decisionHandler(.cancel)
        } else {
            if navigationAction.sourceFrame.isMainFrame {
                latestRedirectURL = navigationAction.request.url
            }
            decisionHandler(.allow)
        }
    }
}
