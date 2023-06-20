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
    private var error: Error?
    private var errorTimer: Timer?

    override init(frame: CGRect, configuration: WKWebViewConfiguration) {
        super.init(frame: frame, configuration: configuration)
        navigationDelegate = self
        addScript(to: configuration)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    private func addScript(to configuration: WKWebViewConfiguration) {
        let sources = sourceTags.map { "\"\($0)\"" }.joined(separator: ",")
        let attributes = sourceAttributes.map { "\"\($0)\"" }.joined(separator: ",")
        let formats = documentExtensions.map { "\"\($0)\"" }.joined(separator: ",")
        let source = """
        window.extractedLinks = getLinksForElement(document);
        window.requestLinks = [];
        var origOpen = XMLHttpRequest.prototype.open;
        XMLHttpRequest.prototype.open = function() {
            this.addEventListener('load', function() {
                if (this.responseURL != null && this.responseURL.length > 0) {
                    window.requestLinks.push(this.responseURL);
                }
            });

            this.addEventListener('load', function() {
                if (this.responseURL != null && this.responseURL.length > 0) {
                    window.requestLinks.push(this.responseURL);
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

        document.addEventListener("load", function(event) {
            startCompletionTimer();
        });
        """
        let script = WKUserScript(source: source, injectionTime: .atDocumentStart, forMainFrameOnly: true)
        configuration.userContentController.addUserScript(script)
    }

    private func startErrorTimer() {
        errorTimer = Timer.scheduledTimer(
            withTimeInterval: 10,
            repeats: false,
            block: { [weak self] timer in
                self?.stopErrorTimer()
                self?.didFinishBlock?(nil, self?.error)
            }
        )
    }
    
    private func stopErrorTimer() {
        errorTimer?.invalidate()
        errorTimer = nil
    }
}

extension OfflineBackgroundWebview: WKNavigationDelegate {

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation, withError error: Error) {
        self.error = error
        startErrorTimer()
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        stopErrorTimer()
        let request = navigationAction.request
        if request.url?.scheme == completionScheme {
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
            decisionHandler(.cancel)
        } else {
            if navigationAction.sourceFrame.isMainFrame {
                latestRedirectURL = navigationAction.request.url
            }
            decisionHandler(.allow)
        }
    }
}
