import Foundation
class OfflineEntryDownloader {
    var config: OfflineDownloaderConfig
    var entry: OfflineDownloaderEntry
    private var task: Task<(), Never>?

    init(entry: OfflineDownloaderEntry, config: OfflineDownloaderConfig) {
        self.entry = entry
        self.config = config
    }

    func start() {
        task = Task {
            do {
                await prepare()
                for part in entry.parts {
                    switch part.value {
                    case let .html(html, baseURL):
                        if part.links.isEmpty {
                            let links = try await OfflineHTMLLinksExtractor(html: html, baseURL: baseURL ?? "").links()
                            part.append(links: links)
                        }
                        
                        for link in part.links where !link.isDownloaded {
                            
                        }
                        print(html)
                    case let.url(url):
                        print(url)
                    }
                }
            } catch {
                print("error = \(error)")
            }
        }
    }

    func download(link: OfflineDownloaderLink, to path: String) async throws {
        if link.isCssLink {
            // Create CSSLoader and wait while it will finish
        } else if link.isVideo {
            // Extract links if need
        } else if link.isIframe {
            // Extract link if need
        } else {

        }
    }

    private func prepare() async {
//        await withCheckedContinuation {[weak self] continuation in
//            guard let self = self else {
//                continuation.resume()
//                return
//            }
//            self.config.preparationBlock?(self.entry) {
//                continuation.resume()
//            }
//        }
    }

    func cancel() {
        task?.cancel()
    }
}
