import Foundation
import SwiftSoup

struct OfflineHTMLDownloader {
/*
    @Injected(\.dataSource) private var dataSource: DataSource
    @Injected(\.mainCssLoader) private var cssLoader: CSSMainLoader

    private let offlineStorage: OfflineStorage = StorageProvider.current

    let pageId: String
    let module: Module
    let html: String
    let path: String
    var shouldWrap: Bool = true
    var baseURL: String?
    let decisionHandler: HTMLDecisionCenter

    func downloadAllLinks(in storage: inout HTMLLinksStorage, to cssFolderPath: String, with progress: Progress, mainStorage: inout HTMLLinksStorage) async throws {
        for link in storage.links {
            if let storageLink = mainStorage.link(for: link), storageLink.isDownloaded {
                var newLink = link
                newLink.setDownloadedLink(storageLink.downloadedLink)
                storage.replace(link: link, with: newLink)
            } else {
                let downloadedLink = try await download(link: link, to: cssFolderPath)
                storage.replace(link: link, with: downloadedLink)
                if let link = mainStorage.link(for: link) {
                    mainStorage.replace(link: link, with: downloadedLink)
                } else {
                    mainStorage.append(link: downloadedLink)
                }
            }
            progress.completedUnitCount += 1
        }
    }

    func download(cssLink: HTMLLink, with progress: Progress, mainStorage: inout HTMLLinksStorage) async throws {
        let cssExtractor = try extractCssLinks(for: cssLink)
        let cssFolderPath = path.appendPath(cssExtractor.path.removeLastPathComponent())
        var cssStorage = cssExtractor.storage()
        let childProgress: Progress = Progress(totalUnitCount: Int64(cssStorage.links.count))
        progress.addChild(childProgress, withPendingUnitCount: 1)
        try await downloadAllLinks(
            in: &cssStorage,
            to: cssFolderPath,
            with: childProgress,
            mainStorage: &mainStorage
        )
        do {
            try replaceCssLink(for: cssExtractor, with: cssStorage)
        } catch {
            throw OfflineHTMLDownloaderError.cantSaveCSS(error: error)
        }
    }

    func download(with mainProgress: Progress) async throws -> HTMLLinksStorage {
        var storage = try await createStorage()
        let cssHelper = CSSOfflineHelper()
        let progress = Progress(totalUnitCount: Int64(storage.links.count))
        mainProgress.addChild(progress, withPendingUnitCount: 1)
        for link in storage.links {
            if link.isCssLink,
                cssHelper.isMainCss(url: link.extractedLink ?? link.link) {
                try await decisionHandler.perform {
                    try cssLoader.copy(to: path)
                    let localCssPath = try cssHelper.pathForOfflineCSS() ?? ""
                    var newLink = link
                    let relativePath = path.appendPath(localCssPath).replacingOccurrences(of: path + "/", with: "")
                    newLink.downloadedLink = relativePath
                    newLink.replaceSource()
                    storage.replace(link: link, with: newLink)
                    progress.completedUnitCount += 1
                }
            } else {
                let downloadedLink = try await decisionHandler.perform {
                    try await downloadLink(link: link, storage: &storage)
                }
                ignore: { worker in
                    worker.newLink(from: link)
                }

                if downloadedLink.isCssLink, downloadedLink.downloadedLink != nil {
                    try await decisionHandler.perform {
                        try await download(cssLink: downloadedLink, with: progress, mainStorage: &storage)
                    } ignore: { _ in
                        progress.completedUnitCount += 1
                    }
                } else {
                    progress.completedUnitCount += 1
                }
            }
        }
        return storage
    }

    private func downloadLink(link: HTMLLink, storage: inout  HTMLLinksStorage) async throws -> HTMLLink {
        let downloadedLink = try await proceed(link: link)
        storage.replace(link: link, with: downloadedLink)
        return downloadedLink
    }

    private func extractCssLinks(for link: HTMLLink) throws -> CSSLinksExtractor {
        if link.isDownloaded,
            let path = link.downloadedLink {
            do {
                let contents = try String(contentsOf: URL(fileURLWithPath: self.path.appendPath(path)))
                let baseURL = link.link
                return CSSLinksExtractor(path: path, contents: contents, baseUrl: baseURL)
            } catch {
                throw OfflineHTMLDownloaderError.cantGetCSSContents(error: error)
            }
        } else {
            throw OfflineHTMLDownloaderError.cantParseCss
        }
    }

    private func replaceCssLink(for extractor: CSSLinksExtractor, with storage: HTMLLinksStorage) throws {
        let path = self.path.appendPath(extractor.path)
        var contents = extractor.contents
        for link in storage.links.sorted(by: { $0.link.count > $1.link.count }) {
            if let localLink = link.downloadedLink,
                let encodedLink = localLink.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) {
                let relativePath = encodedLink.suffix(
                    encodedLink.count - extractor.path.removeLastPathComponent().count - 1
                )
                contents = contents.replacingOccurrences(of: link.link, with: relativePath)
            }
        }
        try FileManager.default.removeItem(atPath: path)
        try contents.write(toFile: path, atomically: true, encoding: .utf8)
    }

    private func iframeVideoLink(from link: HTMLLink) async throws -> HTMLVideoLink {
        do {
            return try await HTMLVideoLinkExtractor(link: link).getVideoLink()
        } catch {
            if error.isOfflineCancel {
                throw error
            }
            throw OfflineHTMLDownloaderError.cantGetVideoLink(error: error)
        }
    }

    private func downloadPoster(for videoLink: HTMLVideoLink) async throws -> String? {
        guard let link = videoLink.posterLink else { return nil }
        let posterLink = HTMLLink(link: link)
        let downloadedLink = try await decisionHandler.perform {
            try await download(link: posterLink, to: path)
        } ignore: { _ in
            posterLink
        }
        return downloadedLink.downloadedLink
    }

    private func shouldUseVideoLinkExtranctor(for link: HTMLLink) -> Bool {
        if link.isIframe {
            return true
        }

        // video js links
        if link.isVideo, link.attribute == "data-setup" {
            return true
        }

        return false
    }

    private func proceed(link: HTMLLink) async throws -> HTMLLink {
        if !link.isDownloaded {
            if shouldUseVideoLinkExtranctor(for: link) {
                let videoLink = try await iframeVideoLink(from: link)
                var newLink = link
                newLink.setExtractedLink(videoLink.url)
                let downloadedLink = try await download(link: newLink, to: path)
                let downloadedPosterLink = try await downloadPoster(for: videoLink)
                if videoLink.isAudio {
                    downloadedLink.replaceIframeWithAudio(
                        name: videoLink.name,
                        playerColor: videoLink.colorString
                    )
                } else {
                    downloadedLink.replaceIframeWithVideo(posterLink: downloadedPosterLink, tracks: videoLink.tracks)
                }
                return downloadedLink
            } else {
                let downloadedLink = try await download(link: link, to: path)
                downloadedLink.replaceSource()
                return downloadedLink
            }
        }

        return link
    }

    private func replacedPolls(in html: String) async throws -> String {
        try await decisionHandler.perform {
            do {
                let pollsData = try decisionHandler.worker.replacedPolls(in: html)
                if pollsData.countOfPolls > 0 {
                    decisionHandler.appendError(OfflineHTMLDownloaderError.replacedPolls(count: pollsData.countOfPolls))
                }
                return pollsData.html
            } catch {
                throw OfflineHTMLDownloaderError.cantReplacePolls(error: error)
            }
        } ignore: { _ in
            html
        }
    }

    private func createStorage() async throws -> HTMLLinksStorage {
        var html = self.html
        html = try await replacedPolls(in: html)

        if shouldWrap {
            html = HTMLCollection().htmlCoveredWithBaseCSS(html)
        }

        if let schemeHandler = dataSource.schemeHandler as? MoodleSchemeHandler {
            html = schemeHandler.correctedHTML(in: html)
        }

        let baseURL = self.baseURL ?? dataSource.schemeHandler.baseHost

        let linksExtractor = HTMLLinksExtractor(html: html, baseURL: baseURL)
        do {
            return try await linksExtractor.storage()
        } catch {
            if error.isOfflineCancel {
                throw error
            }
            throw OfflineHTMLDownloaderError.cantCreateStorage(error: error)
        }
    }

    func download(link: HTMLLink, to folder: String) async throws -> HTMLLink {
        if Task.isCancelled { throw URLError(.cancelled) }

        let urlString = link.extractedLink ?? link.link
        guard let url = URL(string: urlString),
            let request = dataSource.authenticatedStagingRequest(for: url) else {
            throw OfflineHTMLDownloaderError.wrongURL(url: urlString)
        }

        if let linkDTO = await HTMLLinkDTO.isSaved(
            pageId: pageId,
            urlString: urlString,
            path: path,
            storage: offlineStorage
        ) {

            if Task.isCancelled { throw URLError(.cancelled) }

            var downloadedLink = link
            downloadedLink.link = linkDTO.link
            downloadedLink.extractedLink = linkDTO.extractedLink
            downloadedLink.downloadedLink = linkDTO.downloadedLink
            debugLog("Storage downloaded to path = \(downloadedLink.downloadedLink ?? "nil")")
            return downloadedLink
        }

        if Task.isCancelled { throw URLError(.cancelled) }

        debugLog("start download \(url)", "type: (\(module.contentType))" )
        do {
            let (destinationURL, response) = try await URLSession.shared.downloadTask(with: request)
            var downloadedLink = link
            let newURL = self.destinationURL(for: url, with: response, in: folder)

            try FileManager.default.createDirectoryAt(path: newURL.path)
            try FileManager.default.moveItem(at: destinationURL, to: newURL)
            let relativePath = newURL.path.replacingOccurrences(of: self.path + "/", with: "")
            downloadedLink.setDownloadedLink(relativePath)
            downloadedLink.saveDTO(
                path: relativePath,
                pageId: self.pageId,
                moduleId: self.module.id
            ) { _ in }

            return downloadedLink
        } catch {
            if error.isOfflineCancel {
                throw error
            }

            throw OfflineHTMLDownloaderError.cantDownloadFile(url: url.absoluteString, error: error)
        }
    }

    private func path(for url: URL, with response: URLResponse) -> String {
        let path = url.path
        if let last = path.components(separatedBy: "/").last,
            last.contains(".") {
            if response.mimeType?.contains("mp4") == true {
                let nameComponents = last.components(separatedBy: ".")
                return path + "/" + nameComponents[0] + ".mp4"
            }
            if response.mimeType?.contains("audio/mpeg") == true {
                let nameComponents = last.components(separatedBy: ".")
                return path + "/" + nameComponents[0] + ".mp3"
            }
            if response.mimeType?.contains("audio/x-wav") == true {
                let nameComponents = last.components(separatedBy: ".")
                return path + "/" + nameComponents[0] + ".wav"
            }
            return path
        } else if let name = response.suggestedFilename {
            return path + "/" + name
        } else {
            return path + "/" + "\(Date().timeIntervalSince1970).tmp"
        }
    }

    private func alterFilePath(_ filePath: String) -> String {
        var components = filePath.components(separatedBy: "/")
        if let fileName = components.last {
            var fileNameComponents = fileName.components(separatedBy: ".")
            if let name = fileNameComponents.first {
                let newName = name + "\(Date().timeIntervalSince1970)"
                fileNameComponents[0] = newName
            }
            let newName = fileNameComponents.joined(separator: ".")
            components[components.count - 1] = newName
        }
        return components.joined(separator: "/")
    }

    private func destinationURL(for url: URL, with response: URLResponse, in folder: String) -> URL {
        let filePath = path(for: url, with: response)
        var destinationPath = folder.appendPath(filePath)
        if FileManager.default.fileExists(atPath: destinationPath) {
            destinationPath = alterFilePath(destinationPath)
        }
        return URL(fileURLWithPath: destinationPath)
    }
 */
}

extension OfflineHTMLDownloader {
    enum OfflineHTMLDownloaderError: Error, LocalizedError {
        case cantParseCss
        case wrongURL(url: String)
        case unknown
        case cantDownloadFile(url: String, error: Error)
        case cantGetCSSContents(error: Error)
        case cantCreateStorage(error: Error)
        case cantGetVideoLink(error: Error)
        case cantSaveCSS(error: Error)
        case cantReplacePolls(error: Error)
        case replacedPolls(count: Int)

        var errorDescription: String? {
            switch self {
            case .wrongURL(let url):
                return "URL = \"\(url)\" is incorrect and couldn't be downloaded."
            case .unknown:
                return "Unknown error was occured"
            case .cantParseCss:
                return "Can't open or parse CSS file"
            case let .cantDownloadFile(url, error):
                return "Can't download file at: \(url), with error : \(error.localizedDescription)"
            case .cantGetCSSContents(let error):
                return "Can't get contents for downloaded css file. Error: \(error)"
            case .cantCreateStorage(let error):
                return "Can't create storage. Error: \(error)"
            case .cantGetVideoLink(let error):
                return "Can't get video link. Error: \(error)."
            case .cantSaveCSS(let error):
                return "Can't save css. Error: \(error)."
            case .replacedPolls(let count):
                return "Replaced \(count) polls/flips."
            case .cantReplacePolls(let error):
                return "Can't replace polls. Error: \(error)."
            }
        }
    }
}

extension URLSession {
    func downloadTask(with request: URLRequest) async throws -> (URL, URLResponse) {
        if #available(iOS 15.0, *) {
            return try await URLSession.shared.download(for: request)
        } else {
            var task: URLSessionDownloadTask?
            return try await withTaskCancellationHandler {
                try await withCheckedThrowingContinuation { continuation in
                    task = downloadTask(with: request) { url, response, error in
                        if let error = error {
                            continuation.resume(throwing: error)
                        } else if let url = url, let response = response {
                            continuation.resume(returning: (url, response))
                        } else {
                            continuation.resume(throwing: OfflineHTMLDownloader.OfflineHTMLDownloaderError.unknown)
                        }
                    }
                    task?.resume()
                }
            } onCancel: { [weak task] in
                task?.cancel()
            }
        }
    }
}
