import Foundation

class OfflineVideoDownloader {
    var link: OfflineDownloaderLink
    var progress: Progress = Progress()
    var rootPath: String
    var cookieString: String?
    
    init(link: OfflineDownloaderLink, rootPath: String) {
        self.link = link
        self.rootPath = rootPath
    }
    
    func download() async throws {
        guard !link.isDownloaded else { return }
        if link.videoLinks == nil {
            do {
                try await extractVideoLink(for: link)
            } catch {
                if error.isCancelled {
                    throw error
                }
                throw OfflineVideoDownloaderError.cantExtractLink(link: link.extractedLink ?? link.link, error: error)
            }
        }
        
        guard let videoLinks = link.videoLinks else { return }
        
        let links = videoLinks
            .flatMap { [$0.posterLink, $0.extractedLink] }
            .compactMap{ $0 }
        progress.totalUnitCount = Int64(links.count)
        for link in links {
            do {
                try await OfflineLinkDownloader.download(link: link, to: rootPath, with: progress, cookieString: cookieString)
            } catch {
                if error.isCancelled {
                    throw error
                }
                let baseLink = self.link.extractedLink ?? self.link.link
                let linkString = link.extractedLink ?? link.link
                throw OfflineVideoDownloaderError.cantDownloadLink(link: linkString, baseLink: baseLink, error: error)
            }
            
        }
    }

    private func extractVideoLink(for link: OfflineDownloaderLink) async throws {
        let videoLinkExtractor = VideoLinkExtractor(link: link, cookieString: cookieString)
        let videoLinks = try await videoLinkExtractor.getVideoLinks()
        link.videoLinks = videoLinks.map({ videoLink in
            let extractedLink = OfflineDownloaderLink(link: videoLink.url)
            var posterLink: OfflineDownloaderLink?
            if let url = videoLink.posterLink {
                posterLink = OfflineDownloaderLink(link: url)
            }
            return OfflineDownloaderVideoLink(extractedLink: extractedLink, posterLink: posterLink, videoLink: videoLink)
        })
    }
}

extension OfflineVideoDownloader {
    enum OfflineVideoDownloaderError: Error, LocalizedError {
        case cantExtractLink(link: String, error: Error)
        case cantDownloadLink(link: String, baseLink: String, error: Error)
        
        var errorDescription: String? {
            switch self {
            case let .cantExtractLink(link, error):
                return "Can't extract video links for: \(link). Error: \(error)"
            case let .cantDownloadLink(link, baseLink, error):
                return "Can't download video link for: \(link). Base link: \(baseLink). Error: \(error)"
            }
        }
    }
}
