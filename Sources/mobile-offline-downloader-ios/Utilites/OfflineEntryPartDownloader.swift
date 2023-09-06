import Foundation

class OfflineEntryPartDownloader {
    let part: OfflineDownloaderEntryPart
    let rootPath: String
    let htmlIndexName: String
    let shouldCacheCSS: Bool
    let progress: Progress = Progress()
    let linksHandler: OfflineDownloaderConfig.LinksHandlerBlock?
    let errorHandler: OfflineErrorHandler
    
    init(part: OfflineDownloaderEntryPart,
         rootPath: String,
         htmlIndexName: String,
         shouldCacheCSS: Bool = false,
         linksHandler: OfflineDownloaderConfig.LinksHandlerBlock?,
         errorHandler: OfflineErrorHandler
    ) {
        self.part = part
        self.rootPath = rootPath
        self.htmlIndexName = htmlIndexName
        self.shouldCacheCSS = shouldCacheCSS
        self.linksHandler = linksHandler
        self.errorHandler = errorHandler
    }
    
    func download() async throws {
        if Task.isCancelled { throw URLError(.cancelled) }
        switch part.value {
        case let .html(html, baseURL):
            do {
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
                try replaceUnicodeSymbols(in: html).write(toFile: path, atomically: true, encoding: .utf8)
                progress.completedUnitCount = progress.totalUnitCount // completed all units
            } catch {
                if error.isOfflineCancel {
                    throw error
                }
                throw OfflineEntryPartDownloaderError.cantDownloadHTMLPart(error: error)
            }
        case let.url(url):
            do {
                progress.totalUnitCount = 1
                let link = OfflineDownloaderLink(link: url)
                link.extractedLink = linksHandler?(url)
                part.append(links: [link])
                try await OfflineLinkDownloader.download(link: link, to: rootPath, with: progress, cookieString: part.cookieString)
            } catch {
                if error.isOfflineCancel {
                    throw error
                }
                throw OfflineEntryPartDownloaderError.cantDownloadLinkPart(error: error)
            }
        }
    }
    
    private func replaceUnicodeSymbols(in html: String) -> String {
        let replacedString: [String] = html.unicodeScalars.map { scalar -> String in
            if scalar.isASCII {
                return String(scalar)
            } else {
                return "&#x" + String(scalar.value, radix: 16) + ";"
            }
        }

        return replacedString.joined()
    }
    
    private func downloadLinks(with extractor: OfflineHTMLLinksExtractor) async throws {
        for link in part.links {
            print("!!! start download link: \(link.link)")
            var shouldSetRelativePath: Bool = true
            if Task.isCancelled { throw URLError(.cancelled) }
            if !link.isDownloaded {
                if shouldUseVideoDownloader(for: link) {
                    let videoDownloader = OfflineVideoDownloader(link: link, rootPath: rootPath)
                    videoDownloader.cookieString = part.cookieString
                    progress.addChild(videoDownloader.progress, withPendingUnitCount: 1)
                    try await errorHandler.perform {
                        try await videoDownloader.download()
                    } ignore: {
                        if let html = await errorHandler.handler?.replaceHTML(tag: link.tag) {
                            try await errorHandler.perform {
                                try extractor.setHtml(html: html, for: link)
                            }
                            shouldSetRelativePath = false
                        }
                    }
                } else if link.isCssLink {
                    let cssDownloader = OfflineCSSLinkDownloader(link: link, rootPath: rootPath, shouldCache: shouldCacheCSS, linksHandler: linksHandler)
                    cssDownloader.cookieString = part.cookieString
                    progress.addChild(cssDownloader.progress, withPendingUnitCount: 1)
                    try await errorHandler.perform {
                        try await cssDownloader.download()
                    }
                } else {
                    try await errorHandler.perform {
                        try await OfflineLinkDownloader.download(link: link, to: rootPath, with: progress, cookieString: part.cookieString)
                    } ignore: {
                        if let html = await errorHandler.handler?.replaceHTML(tag: link.tag) {
                            try await errorHandler.perform {
                                try extractor.setHtml(html: html, for: link)
                            }
                            shouldSetRelativePath = false
                        }
                    }
                }
            } else {
                progress.completedUnitCount += 1
            }

            if shouldSetRelativePath {
                try extractor.setRelativePath(for: link)
            }
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

//extension OfflineEntryPartDownloader {
public enum OfflineEntryPartDownloaderError: Error, LocalizedError {
    case cantDownloadHTMLPart(error: Error)
    case cantDownloadLinkPart(error: Error)
    
    public var errorDescription: String? {
        switch self {
        case let .cantDownloadHTMLPart(error):
            return "Can't download HTML part. Error: \(error)"
        case let .cantDownloadLinkPart(error):
            return "Can't download link part. Error: \(error)"
        }
    }
}
//}
