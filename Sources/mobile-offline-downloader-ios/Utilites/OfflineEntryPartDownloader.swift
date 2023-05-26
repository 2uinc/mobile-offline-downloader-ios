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
                    
                    if link.isVideo {
                        // Extract links if need
                    }
                    
                    if link.isIframe {
                        let videoLinkExtractor = VideoLinkExtractor(link: link.link)
                        let videoLink = try await videoLinkExtractor.getVideoLink()
                        link.extractedLink = videoLink.url
                        
                        if let posterString = videoLink.posterLink {
                            let posterLink = OfflineDownloaderLink(link: posterString)
                            try await download(link: posterLink, to: rootPath, includeToProgress: false)
                        }
                        
                        //TODO: download poster, subtitles and replace
                    }
                    print("ALARM: \(link.link.hashValue) \(link.link.sha256())")
                    // TODO: add progress for file
                    try await download(link: link, to: rootPath)
                    // TODO: add progress for file
                    
                    if link.isCssLink {
                        // Create CSSLoader and wait while it will finish
                        // Parse css
                        // Downoad all css links
                        // Replace links in css to saved links
                        // Copy CSS
                        // Replace css to saved
                        print("CSS link")
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
            try await download(link: link, to: rootPath)
        }
    }
    
    private func download(link: OfflineDownloaderLink, to path: String, includeToProgress: Bool = true) async throws {
        let downloader = OfflineLinkDownloader()
        if includeToProgress {
            progress.addChild(downloader.progress, withPendingUnitCount: 1)
        }
        let url = try await downloader.download(urlString: link.extractedLink ?? link.link, toFolder: path)
        let relativePath = url.filePath.replacingOccurrences(of: path + "/", with: "")
        link.downloadedRelativePath = relativePath
    }
}
