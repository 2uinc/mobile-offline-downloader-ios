import Foundation

class OfflineEntryPartDownloader {
    var part: OfflineDownloaderEntryPart
    var rootPath: String
    var htmlIndexName: String
    var shouldCacheCSS: Bool
    var progress: Progress = Progress()
    
    init(part: OfflineDownloaderEntryPart, rootPath: String, htmlIndexName: String, shouldCacheCSS: Bool = false) {
        self.part = part
        self.rootPath = rootPath
        self.htmlIndexName = htmlIndexName
        self.shouldCacheCSS = shouldCacheCSS
    }
    
    func download() async throws {
        if Task.isCancelled { throw URLError(.cancelled) }
        switch part.value {
        case let .html(html, baseURL):
            let extractor = try OfflineHTMLLinksExtractor(html: html, baseURL: baseURL ?? "")
            try FileManager.default.createDirectoryAt(path: rootPath)
            if Task.isCancelled { throw URLError(.cancelled) }
            if part.links.isEmpty {
                let links = try await extractor.links()
                part.append(links: links)
            }
            
            if part.links.isEmpty {
                progress.totalUnitCount = 1
            } else {
                progress.totalUnitCount = Int64(part.links.count)
            }

            try await downloadLinks(with: extractor)
            let html = try extractor.finalHTML()
            let path = rootPath.appendPath(htmlIndexName)
            try html.write(toFile: path, atomically: true, encoding: .utf8)
            progress.completedUnitCount = progress.totalUnitCount // completed all units
        case let.url(url):
            progress.totalUnitCount = 1
            let link = OfflineDownloaderLink(link: url)
            part.append(links: [link])
            try await OfflineLinkDownloader.download(link: link, to: rootPath, with: progress, cookieString: part.cookieString)
        }
    }
    
    private func downloadLinks(with extractor: OfflineHTMLLinksExtractor) async throws {
        for link in part.links {
            if !link.isDownloaded {
                if shouldUseVideoDownloader(for: link) {
                    let videoDownloader = OfflineVideoDownloader(link: link, rootPath: rootPath)
                    progress.addChild(videoDownloader.progress, withPendingUnitCount: 1)
                    try await videoDownloader.download()
                } else if link.isCssLink {
                    let cssDownloader = OfflineCSSLinkDownloader(link: link, rootPath: rootPath, shouldCache: shouldCacheCSS)
                    progress.addChild(cssDownloader.progress, withPendingUnitCount: 1)
                    try await cssDownloader.download()
                } else {
                    try await OfflineLinkDownloader.download(link: link, to: rootPath, with: progress, cookieString: part.cookieString)
                }
            } else {
                progress.completedUnitCount += 1
            }

            try extractor.setRelativePath(for: link)
        }
    }
    
    private func shouldUseVideoDownloader(for link: OfflineDownloaderLink) -> Bool {
        if link.isVideo && link.attribute == "data-setup" {
            return true
        }

        if link.isIframe {
            return true
        }

        if VideoTypeDetector(link: link.link).isWistiaJSON {
            return true
        }
        
        return false
    }
}
