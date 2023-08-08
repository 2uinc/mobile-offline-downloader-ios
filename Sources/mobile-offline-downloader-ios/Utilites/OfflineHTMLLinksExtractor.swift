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

        if let elements = try mediaElements(for: link) {
            if link.isScript {
                try replaceVideoPathForScript(with: link, and: elements)
            } else {
                try replace(link: link, with: elements)
            }
        } else {
            try replacePath(for: link)
        }
    }
    
    private func mediaElements(for link: OfflineDownloaderLink) throws -> [Element]? {
        guard link.isDownloaded, let videoLinks = link.videoLinks else { return nil }
        var elements: [Element] = []
        for link in videoLinks {
            if link.videoLink.isAudio {
                if let audioElement = try audioElement(from: link) {
                    elements.append(audioElement)
                }
            } else  {
                if let videoElement = try videoElement(from: link) {
                    elements.append(videoElement)
                }
            }
        }
        
        return elements
    }

    private func replace(link: OfflineDownloaderLink, with elements: [Element]) throws {
        guard link.isDownloaded,
              let tagName = link.tag,
              let attributeName = link.attribute
        else { return }
        
        let tags = try document.getElementsByTag(tagName)
        for tag in tags {
            if let linkString = try? tag.attr(attributeName),
               !linkString.isEmpty,
               linkString.fixLink(with: baseURL) == link.link {
                let element = try container(for: elements)
                for container in config.mediaContainerClasses {
                    if let parent = parent(
                        for: container,
                        from: tag
                    ) {
                        try parent.replaceWith(element)
                        return
                    }
                }
                
                try tag.replaceWith(element)
            }
        }
    }
        
    private func container(for elements: [Element]) throws -> Element {
        let container = Element(Tag("div"), "")
        for element in elements {
            try container.append(try element.outerHtml())
        }
        
        return container
    }
    
    private func replaceVideoPathForScript(with link: OfflineDownloaderLink, and elements: [Element]) throws {
        guard link.isDownloaded,
              let tagName = link.tag,
              let attributeName = link.attribute
        else { return }
        
        if let id = link.link.lastPathComponent().components(separatedBy: ".").first {
            let tags = try document.getElementsByClass("wistia_async_\(id)")
            for tag in tags {
                let centerElement = try container(for: elements)
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
        
        // remove scripts
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
    
    private func videoElement(from link: OfflineDownloaderVideoLink) throws -> Element? {
        guard let relativePath = link.extractedLink.downloadedRelativePath else { return nil }
        let videoLink = link.videoLink
        
        let centerElement = Element(Tag("center"), "")
        var posterAttribute = ""
        if let posterLink = link.posterLink?.downloadedRelativePath {
            posterAttribute = "poster=\"\(posterLink)\""
        }

        var trackTags = ""
        let tracks = videoLink.tracks
        if !tracks.isEmpty {
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
    
    private func audioElement(from link: OfflineDownloaderVideoLink) throws -> Element? {
        guard let relativePath = link.extractedLink.downloadedRelativePath else { return nil }
        let videoLink = link.videoLink
        
        var color = config.defaultMediaBackground
        if let colorString = videoLink.colorString {
            color = colorString
        }
        let name = videoLink.name
        
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
    
    func finalHTML() throws -> String {
        let metas = try document.getElementsByAttributeValue("name", "viewport")
        if metas.isEmpty() {
            let meta = Element(Tag("meta"), "")
            try meta.attr("name", "viewport")
            try meta.attr("content", "width=device-width, initial-scale=1")
            try document.head()?.addChildren(meta)
        }
        return try document.html()
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
                        attribute: attr,
                        typeAttribute: try? tag.attr("type"),
                        tagHTML: try? tag.outerHtml()
                    )
                    webLink.extractedLink = extractedLink(for: webLink.link)
                    
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
                        attribute: attr,
                        typeAttribute: try? tag.attr("type"),
                        tagHTML: try? tag.html()
                    )
                    webLink.extractedLink = extractedLink(for: webLink.link)
                    links.append(webLink)
                }
            }
        }
        return links
    }
    
    private func extractedLink(for linkString: String) -> String? {
        if let link = config.linksHandler?(linkString).fixLink(with: baseURL),
           link != linkString {
            return link
        }
        return nil
    }

    private func canLoad(link: String, for tagName: String) -> Bool {
        if link.range(of: "data:(.*?)base64", options: .regularExpression) != nil {
            return false
        }

        if tagName.lowercased() == "a" {
            if let _ = extractedLink(for: link) {
                return true
            }
            
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
