import Foundation
import SwiftSoup

struct OfflineHTMLLinksExtractor: OfflineLinksExtractorProtocol, OfflineHTMLLinksExtractorProtocol, HTMLSoupHelperProtocol {

    var html: String
    var baseURL: String
    private let config = OfflineDownloadsManager.shared.config
    private var document: SwiftSoup.Document

    init(html: String, baseURL: String) throws {
        self.html = html
        self.baseURL = baseURL
        self.document = try SwiftSoup.parse(html)
    }
    
    func links() async throws -> [OfflineDownloaderLink] {
        if Task.isCancelled { throw URLError(.cancelled) }
        do {
            var links: [OfflineDownloaderLink] = []
            for tag in sourceTags {
                let tagLinks = try linksForTag(tag)
                links.append(contentsOf: tagLinks)
            }
            return links
        } catch {
            throw OfflineHTMLLinksExtractorError.soupError(error: error)
        }
    }
    
    func setRelativePath(for link: OfflineDownloaderLink) throws {
        guard link.isDownloaded else { return }

        if link.videoLink != nil {
            if link.isAudio {
                try replacePathForAudio(with: link)
            } else if link.isVideo {
                try replacePathForVideo(with: link)
            } else if link.isIframe {
                try replaceVideoPathForIframe(with: link)
            } else if link.isScript {
                try replaceVideoPathForScript(with: link)
            }
        } else {
            try replacePath(for: link)
        }
    }
    private func replaceVideoPathForIframe(with link: OfflineDownloaderLink) throws {
        guard link.isDownloaded, let videoLink = link.videoLink else { return }
        if videoLink.videoLink.isAudio {
            try replacePathForAudio(with: link)
        } else  {
            try replacePathForVideo(with: link)
        }
    }

    private func replaceVideoPathForScript(with link: OfflineDownloaderLink) throws {
        guard link.isDownloaded,
              let tagName = link.tag,
              let attributeName = link.attribute,
              let videoLink = link.videoLink
        else { return }
        
        if let id = link.link.lastPathComponent().components(separatedBy: ".").first {
            let tags = try document.getElementsByClass("wistia_async_\(id)")
            for tag in tags {
                var element: Element?
                if videoLink.videoLink.isAudio {
                    element = try audioElement(from: link)
                } else {
                    element = try videoElement(from: link)
                }
                
                if let centerElement = element {
                    for container in config.mediaContainerClasses {
                        if let parent = parent(
                            for: container,
                            from: tag
                        ) {
                            try parent.replaceWith(centerElement)
                            return
                        }
                    }
                    
                    try tag.replaceWith(centerElement)
                }
            }
        }
        
        let scripts = try document.getElementsByTag(tagName)
        for script in scripts {
            if let linkString = try? script.attr(attributeName),
                !linkString.isEmpty,
                linkString.fixLink(with: baseURL) == link.link {
                try script.remove()
            }
        }
    }
    
    private func replacePath(for link: OfflineDownloaderLink) throws {
        guard link.isDownloaded,
              let tagName = link.tag,
              let attributeName = link.attribute,
              let relativePath = link.downloadedRelativePath
        else { return }

        let tags = try document.getElementsByTag(tagName)
        for tag in tags {
            if let linkString = try? tag.attr(attributeName),
                !linkString.isEmpty,
                linkString.fixLink(with: baseURL) == link.link {
                try tag.attr(attributeName, relativePath)
            }
        }
    }
    
    private func videoElement(from link: OfflineDownloaderLink) throws -> Element? {
        guard link.isDownloaded,
              let relativePath = link.downloadedRelativePath
        else { return nil }
        
        let centerElement = Element(Tag("center"), "")
        var posterAttribute = ""
        if let posterLink = link.videoLink?.posterLink?.downloadedRelativePath {
            posterAttribute = "poster=\"\(posterLink)\""
        }

        var trackTags = ""
        if let tracks = link.videoLink?.videoLink.tracks, !tracks.isEmpty {
            for track in tracks {
                if let base64String = track.contents.data(using: .utf8)?.base64EncodedString() {
                    let trackTag = """
                        <track kind="captions" srclang="\(track.language)" src="data:text/vtt;base64,\(base64String)"> \n
                    """
                    trackTags.append(trackTag)
                }
            }

        }
        
        let htmlToInsert: String = """
            <video preload="auto" controls="true" \(posterAttribute) >
                <source src=\(relativePath) type="video/mp4">
                \(trackTags)
            </video>
        """
        try centerElement.append(htmlToInsert)
        return centerElement
    }
    
    private func replacePathForVideo(with link: OfflineDownloaderLink) throws {
        guard link.isDownloaded,
              let tagName = link.tag,
              let attributeName = link.attribute
        else { return }
        
        let tags = try document.getElementsByTag(tagName)
        for tag in tags {
            if let linkString = try? tag.attr(attributeName),
                !linkString.isEmpty,
                linkString.fixLink(with: baseURL) == link.link {
                
                if let centerElement = try videoElement(from: link) {
                    for container in config.mediaContainerClasses {
                        if let parent = parent(
                            for: container,
                            from: tag
                        ) {
                            try parent.replaceWith(centerElement)
                            return
                        }
                    }
                    
                    try tag.replaceWith(centerElement)
                }
            }
        }
    }
    
    private func audioElement(from link: OfflineDownloaderLink) throws -> Element? {
        guard link.isDownloaded,
              let relativePath = link.downloadedRelativePath,
              let videoLink = link.videoLink
        else { return nil }
        
        var color = config.defaultMediaBackground
        if let colorString = videoLink.videoLink.colorString {
            color = colorString
        }
        let name = videoLink.videoLink.name
        
        let centerElement = Element(Tag("center"), "")
        let htmlToInsert: String = """
        <div class = "offlineAudioTitle" style = "position: relative;">
            <div style="background-color: \(color);
                display:flex;
                align-items: center;
                height: calc(100vw/(16/9));">
                <p style="color: white;">\(name)</p>
            </div>
            <audio controls="true" preload="auto" style="width: 100%; position:absolute; left:0; bottom:0;">
                <source src="\(relativePath)" type="audio/mp3">
            </audio>
        </div>
        """
        try centerElement.append(htmlToInsert)
        return centerElement
    }
    
    private func replacePathForAudio(with link: OfflineDownloaderLink) throws {
        guard link.isDownloaded,
              let tagName = link.tag,
              let attributeName = link.attribute
        else { return }

        let tags = try document.getElementsByTag(tagName)
        for tag in tags {
            if let linkString = try? tag.attr(attributeName),
                !linkString.isEmpty,
                linkString.fixLink(with: baseURL) == link.link {
                if let centerElement = try audioElement(from: link) {
                    for container in config.mediaContainerClasses {
                        if let parent = parent(
                            for: container,
                            from: tag
                        ) {
                            try parent.replaceWith(centerElement)
                            return
                        }
                    }
                    
                    try tag.replaceWith(centerElement)
                }
            }
        }
    }
    
    func finalHTML() throws -> String {
        try document.html()
    }

    private func linksForTag(_ name: String) throws -> [OfflineDownloaderLink] {
        var links: [OfflineDownloaderLink] = []
        let tags = try document.getElementsByTag(name)
        for tag in tags {
            for attr in sourceAttributes {
                if let link = try? tag.attr(attr),
                    !link.isEmpty,
                    canLoad(link: link, for: name) {
                    let webLink = OfflineDownloaderLink(
                        link: link.fixLink(with: baseURL),
                        tag: tag.tagName(),
                        attribute: attr
                    )
                    links.append(webLink)
                }
            }

            // get youtube or vimeo link from videoJS
            if name.lowercased() == "video" {
                let attr = "data-setup"
                if let jsonString = try? tag.attr(attr),
                    let jsonData = jsonString.data(using: .utf8),
                    let pluginObject = try? JSONDecoder().decode(
                        YoutubeAndVimeoPlugin.self,
                        from: jsonData
                    ),
                    let source = pluginObject.sources.first {
                    let link = source.src
                    let webLink = OfflineDownloaderLink(
                        link: link.fixLink(with: baseURL),
                        tag: tag.tagName(),
                        attribute: attr
                    )
                    links.append(webLink)
                }
            }
        }
        return links
    }

    private func canLoad(link: String, for tagName: String) -> Bool {
        if link.range(of: "data:(.*?)base64", options: .regularExpression) != nil {
            return false
        }

        if tagName.lowercased() == "a" {
            if let url = URL(string: link) {
                let fileName = url.path.lowercased()
                let fileExtension = fileName.components(separatedBy: ".").last ?? fileName
                return documentExtensions.contains(fileExtension)
            } else {
                return false
            }
        }

        return true
    }
}

extension OfflineHTMLLinksExtractor {
    enum OfflineHTMLLinksExtractorError: Error, LocalizedError {
        case soupError(error: Error)

        var errorDescription: String? {
            switch self {
            case .soupError(error: let error):
                return "HTMLLinksExtractor got an error: \(error)"
            }
        }
    }
}
