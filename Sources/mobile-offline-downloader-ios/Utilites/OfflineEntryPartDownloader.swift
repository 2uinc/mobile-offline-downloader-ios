import Foundation

class OfflineEntryPartDownloader {
    var part: OfflineDownloaderEntryPart
    var rootPath: String
    var htmlIndexName: String
    var progress: Progress = Progress()
    
    init(part: OfflineDownloaderEntryPart, rootPath: String, htmlIndexName: String) {
        self.part = part
        self.rootPath = rootPath
        self.htmlIndexName = htmlIndexName
    }
    
    func download() async throws {
        if Task.isCancelled { throw URLError(.cancelled) }
        switch part.value {
        case let .html(html, baseURL):
            let extractor = try OfflineHTMLLinksExtractor(html: html, baseURL: baseURL ?? "")
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

            for link in part.links {
                if !link.isDownloaded {
                    if shouldUseVideoDownloader(for: link) {
                        let videoDownloader = OfflineVideoDownloader(link: link, rootPath: rootPath)
                        progress.addChild(videoDownloader.progress, withPendingUnitCount: 1)
                        try await videoDownloader.download()
                    } else if link.isCssLink {
                        print("ALARM: \(link.link.hashValue) \(link.link.sha256())")
                        // Create CSSLoader and wait while it will finish
                        // Parse css
                        // Downoad all css links
                        // Replace links in css to saved links
                        // Copy CSS
                        // Replace css to saved
                        print("CSS link")
                    } else {
                        try await OfflineLinkDownloader.download(link: link, to: rootPath, with: progress)
                    }
                } else {
                    progress.completedUnitCount += 1
                }

                try extractor.setRelativePath(for: link)
            }
            let html = try extractor.finalHTML()
            let path = rootPath.appendPath(htmlIndexName)
            try html.write(toFile: path, atomically: true, encoding: .utf8)
            progress.completedUnitCount = progress.totalUnitCount // completed all units
        case let.url(url):
            progress.totalUnitCount = 1
            let link = OfflineDownloaderLink(link: url)
            part.append(links: [link])
            try await OfflineLinkDownloader.download(link: link, to: rootPath, with: progress)
        }
    }
    
    private func shouldUseVideoDownloader(for link: OfflineDownloaderLink) -> Bool {
        if link.isVideo && link.attribute == "data-setup" {
            return true
        }

        if link.isIframe {
            return true
        }

        return false
    }
}
