import Foundation

struct VideoLink: Codable {
    var name: String
    var url: String
    var isAudio: Bool
    var posterLink: String?
    var colorString: String?
    var tracks: [VideoTrack] = []
}

struct VideoTrack: Codable {
    var name: String
    var language: String
    var contents: String
}

struct VideoLinkExtractor {
    var link: String
    var baseHost: String = ""
    var cookieString: String?

    func getVideoLink() async throws -> VideoLink {
        let type = VideoTypeDetector(link: link).type
        switch type {
        case .wistia:
            return try await getWistiaLink()
        case .vimeo:
            return try await getVimeoLink()
        case .hapyak:
            return try await getHapyakLink()
        case .wistiaJSON:
            return try await getWistiaJsonLink()
        case .youtube, .eco:
            throw VideoLinkExtractorError.unsupportedType(src: link, type: type)
        default:
            throw VideoLinkExtractorError.unknownType(src: link)
        }
    }

    private func getContents(for urlString: String) async throws -> String {
        if Task.isCancelled { throw URLError(.cancelled) }
        do {
            let downloader = OfflineLinkDownloader()
            downloader.additionCookies = cookieString
            return try await downloader.contents(urlString: urlString)
        } catch {
            throw VideoLinkExtractorError.cantGetContents(
                src: urlString,
                error: error
            )
        }
    }

    private func getDynamicStorage(from url: URL) async throws -> (links:[OfflineDownloaderLink], html: String?) {
        do {
            let extractor = await OfflineHTMLDynamicsLinksExtractor(url: url)
            try await extractor.fetch()
            let links = try await extractor.links()
            let html = await extractor.html
            return (links: links, html: html)
        } catch {
            if error.isOfflineCancel {
                throw error
            }
            throw VideoLinkExtractorError.cantGetDynamicStorage(src: url.absoluteString, error: error)
        }
    }

    private func decode<T: Decodable>(json: String, with type: T.Type) throws -> T {
        guard let data = json.data(using: .utf8)
        else {
            throw VideoLinkExtractorError.badJSON(json: json, src: link)
        }

        let decoder = JSONDecoder()
        do {
            return try decoder.decode(type, from: data)
        } catch {
            throw VideoLinkExtractorError.decodeFailed(src: link, error: error)
        }
    }
    private func getVimeoVideo(from content: String, isEmbed: Bool = false) async throws -> VimeoVideo {
        let jsonBodies: [String] = [
            content.slice(fromStr: "var config = {", toStr: "};"),
            content.slice(fromStr: "playerConfig = {", toStr: "};"),
            content.slice(fromStr: "playerConfig = {", toStr: "}\n"),
            content.slice(fromStr: "playerConfig = {", toStr: "}</script>")
        ].compactMap { $0 }
        if !jsonBodies.isEmpty {
            var jsonErrors: [Error] = []
            for jsonBody in jsonBodies {
                let json = "{ \(jsonBody) }"
                do {
                    let video = try decode(json: json, with: VimeoVideo.self)
                    return video
                } catch {
                    jsonErrors.append(error)
                }
            }
            throw VideoLinkExtractorError.cantParseJsons(src: link, errors: jsonErrors)
        } else {
            if !isEmbed,
               let embedUrl = content.slice(fromStr: "embedUrl\":\"", toStr: "\"") {
                let contents = try await getContents(for: embedUrl)
                return try await getVimeoVideo(from: contents, isEmbed: true)
            }
            throw VideoLinkExtractorError.noJSON(src: link)
        }
    }

    private func getVimeoLink() async throws -> VideoLink {
        let link = link.fixLink(with: baseHost)

        let content = try await getContents(for: link)
        let video = try await getVimeoVideo(from: content)

        if let url = video.request.files.progressive.min(by: { $0.height < $1.height })?.url {
            var tracks: [VideoTrack] = []
            let playerURL = video.playerURL

            for track in video.request.textTracks ?? [] {
                var subtitleUrl = track.url
                if subtitleUrl.prefix(1) == "/" {
                    subtitleUrl = playerURL + subtitleUrl
                    if subtitleUrl.prefix(4) != "http" {
                        subtitleUrl = "https://\(subtitleUrl)"
                    }
                }
                do {
                    let contents = try await getContents(for: url)
                    tracks.append(VideoTrack(name: track.label, language: track.lang, contents: contents))
                } catch {
                    // ignore error
                }
            }

            return VideoLink(
                name: "",
                url: url,
                isAudio: false,
                posterLink: video.video.thumbs["base"],
                tracks: tracks
            )
        } else {
            throw VideoLinkExtractorError.noCompatibleVideo(src: link)
        }
    }

    private func getLink(from wistia: WistiaVideo, with tracks: [VideoTrack]) -> VideoLink? {
        let poster = wistia.assets
            .filter { $0.type.lowercased().contains("still_image") }
            .max { ($0.width ?? 0) > ($1.width ?? 0) }?.url

        let originalAsset = wistia.assets.first { $0.type == "original" }

        if wistia.mediaType.lowercased() == "audio" {
            let audioAssets = wistia.assets.filter { $0.type == "mp3_audio" }
            let betterAudio = audioAssets.max { $0.size ?? 0 > $1.size ?? 0 }
            if let url = betterAudio?.url ?? originalAsset?.url {
                return VideoLink(
                    name: wistia.name,
                    url: url,
                    isAudio: true,
                    posterLink: poster,
                    colorString: wistia.options.playerColor,
                    tracks: tracks
                )
            }
        } else {
            let videoAssets = wistia.assets.filter { $0.codec == "h264" }
            let betterVideo = videoAssets.min { $0.size ?? 0 < $1.size ?? 0 }
            if let url = betterVideo?.url ?? originalAsset?.url {
                return VideoLink(
                    name: wistia.name,
                    url: url,
                    isAudio: false,
                    posterLink: poster,
                    colorString: wistia.options.playerColor,
                    tracks: tracks
                )
            }
        }
        return nil
    }

    private func getLink(from video: HapyakVideo, thumbnailURL: String?) async -> VideoLink? {
        let poster = thumbnailURL ?? video.media.assets
            .filter { $0.type.lowercased().contains("still_image") }
            .max { $0.width > $1.width }?.url

        let originalAsset = video.media.assets.first { $0.type == "original" }

        var tracks: [VideoTrack] = []
        if let hashedId = video.media.hashedId {
            do {
                tracks = try await getWistiaSubtitles(id: hashedId)
            } catch {
                // ignore error
            }
        }

        if video.media.mediaType.lowercased() == "audio" {
            let audioAssets = video.media.assets.filter { $0.type == "mp3_audio" }
            let betterAudio = audioAssets.max { $0.intSize > $1.intSize }
            if let url = betterAudio?.url ?? originalAsset?.url {
                return VideoLink(name: "", url: url, isAudio: true, posterLink: poster, tracks: tracks)
            }
        } else {
            let videoAssets = video.media.assets.filter { $0.codec == "h264" }
            let betterVideo = videoAssets.min { $0.intSize < $1.intSize }
            if let url = betterVideo?.url ?? originalAsset?.url {
                return VideoLink(name: "", url: url, isAudio: false, posterLink: poster, tracks: tracks)
            }
        }
        return nil
    }

    private func getWistiaSubtitles(id: String) async throws -> [VideoTrack] {
        let subtitleJsonURL = "https://fast.wistia.net/embed/captions/\(id).json"
        let subtitleContent = try await getContents(for: subtitleJsonURL)
        let wistiaCaptions = try decode(json: subtitleContent, with: WistiaSubtitles.self)
        let dateFormatter = DateFormatter()
        dateFormatter.timeZone = TimeZone(identifier: "UTC")
        dateFormatter.dateFormat = "HH:mm:ss.SSS"

        var tracks: [VideoTrack] = []
        for caption in wistiaCaptions.captions {
            if let hash = caption.hash {
                let lines = hash.lines
                if !lines.isEmpty {
                    var subtitle = "WEBVTT\n\n"
                    for line in lines {
                        let start = dateFormatter.string(from: Date(timeIntervalSinceReferenceDate: line.start))
                        let end = dateFormatter.string(from: Date(timeIntervalSinceReferenceDate: line.end))
                        subtitle.append(start + " --> " + end + "\n")
                        subtitle.append(line.text.joined(separator: "\n"))
                        subtitle.append("\n")
                        subtitle.append("\n")
                    }
                    let track = VideoTrack(
                        name: caption.englishName,
                        language: caption.language,
                        contents: subtitle
                    )
                    tracks.append(track)
                }
            }
        }
        return tracks
    }

    private func getWistiaVideo(from content: String) throws -> WistiaVideo {
        let jsonBodies: [String] = [
            content.slice(fromStr: "iframeInit(", toStr: ", {});"),
            content.slice(fromStr: "W.embed(", toStr: ", embedOptions);")
        ].compactMap { $0 }
        if !jsonBodies.isEmpty {
            var jsonErrors: [Error] = []
            for json in jsonBodies {
                do {
                    return try decode(json: json, with: WistiaVideo.self)
                } catch {
                    jsonErrors.append(error)
                }
            }
            throw VideoLinkExtractorError.cantParseJsons(src: link, errors: jsonErrors)
        } else {
            throw VideoLinkExtractorError.noJSON(src: link)
        }
    }
    
    private func getWistiaJsonLink() async throws -> VideoLink {
        let content: String = try await getContents(for: link)
        if let json = content.slice(fromStr: "= {", toStr: "};") {
            let jsonBody = "{\(json)}"
            let wistia = try decode(json: jsonBody, with: WistiaJSON.self)
            return try await getWistiaLink(from: wistia.media)
        }
        throw VideoLinkExtractorError.noJSON(src: link)
    }

    private func getWistiaLink() async throws -> VideoLink {
        let link = link.fixLink(with: baseHost)
        let content = try await getContents(for: link)
        let wistia = try getWistiaVideo(from: content)
        return try await getWistiaLink(from: wistia)
    }

    private func getWistiaLink(from wistia: WistiaVideo) async throws -> VideoLink {
        var tracks: [VideoTrack] = []
        do {
            tracks = try await getWistiaSubtitles(id: wistia.hashedId)
        } catch {
            // ignore error
        }
        if let link = getLink(from: wistia, with: tracks) {
            return link
        } else {
            throw VideoLinkExtractorError.noCompatibleVideo(src: link)
        }
    }
    
    private func getHapyakLink() async throws -> VideoLink {
        let link = link.fixLink(with: baseHost)
        guard let url = URL(string: link) else { throw VideoLinkExtractorError.badSrc(src: link) }
        let storage = try await getDynamicStorage(from: url)
        if
            let content = storage.html,
            let sourceId = content.slice(fromStr: "\"source_id\": \"", toStr: "\"") {

            if
                let jsonLink = storage.links.first(where: { $0.link.contains("/medias/\(sourceId).json") })?.link,
                let jsonURL = URL(string: jsonLink) {

                var jsonBody = try await getContents(for: jsonLink)

                let urlComponents = URLComponents(url: jsonURL, resolvingAgainstBaseURL: false)
                if let callback = urlComponents?.queryItems?.first(where: { $0.name == "callback" })?.value {
                    jsonBody = jsonBody.replacingOccurrences(of: "/**/\(callback)(", with: "")
                    let startIndex = jsonBody.startIndex
                    let endIndex = jsonBody.index(jsonBody.endIndex, offsetBy: -1)
                    jsonBody = String(jsonBody[startIndex ..< endIndex])
                }
                let thumbnailURL = content.slice(fromStr: "thumbnailUrl\":\"", toStr: "\"")
                let video = try decode(json: jsonBody, with: HapyakVideo.self)
                if let link = await getLink(from: video, thumbnailURL: thumbnailURL) {
                    return link
                } else {
                    throw VideoLinkExtractorError.noCompatibleVideo(src: link)
                }
            } else if let iframeLink = storage.links.first(where: { $0.isIframe && $0.link.contains(sourceId) }) {
                let extractor = VideoLinkExtractor(link: iframeLink.link)
                return try await extractor.getVideoLink()
            } else if let embedUrl = content.slice(fromStr: "embedUrl\":\"", toStr: "\"") {
                let link = embedUrl.fixLink(with: baseHost)
                let extractor = VideoLinkExtractor(link: link)
                return try await extractor.getVideoLink()
            } else {
                throw VideoLinkExtractorError.noJSON(src: link)
            }
        } else {
            throw VideoLinkExtractorError.noJSON(src: link)
        }
    }
}

extension VideoLinkExtractor {
    enum VideoLinkExtractorError: Error, LocalizedError {
        case unknownType(src: String)
        case badSrc(src: String)
        case noJSON(src: String)
        case badJSON(json: String, src: String)
        case noCompatibleVideo(src: String)
        case decodeFailed(src: String, error: Error)
        case unsupportedType(src: String, type: VideoTypeDetector.VideoType)
        case cantGetContents(src: String, error: Error)
        case cantGetDynamicStorage(src: String, error: Error)
        case cantGetDynamicHTML(src: String, error: Error)
        case cantParseJsons(src: String, errors: [Error])
        case cantGetWistiaSubtitles(src: String, error: Error?)

        var errorDescription: String? {
            switch self {
            case .unknownType(let link) :
                return "Unknown type of iframe source. Src = \(link)."
            case .badSrc(let link):
                return "Can't produce src: \(link)"
            case .noJSON(let link):
                return "Can't extract video JSON. Src = \(link)"
            case let .badJSON(json, link):
                return "Can't produce JSON: \(json). Src = \(link)"
            case .noCompatibleVideo(let link):
                return "There no compatible video to play. Src = \(link)"
            case let .decodeFailed(link, error):
                return "Can't decode json for src = \(link). Error = \(error)"
            case let .unsupportedType(src, type):
                return "Unsupported type: \(type). Src = \(src)"
            case let .cantGetContents(src: src, error: error):
                return "Can't get content for \(src). Error: \(error)"
            case let .cantGetDynamicStorage(src: src, error: error):
                return "Can't get dynamic storage for \(src). Error: \(error)"
            case let .cantGetDynamicHTML(src, error):
                return "Can't get dynamic html for src: \(src). Error: \(error)"
            case let .cantParseJsons(src, errors):
                return "Can't parse json for src: \(src). Errors: \(errors)."
            case let .cantGetWistiaSubtitles(src, error):
                if let error = error {
                    return "Can't get wistia subtitles for src: \(src). Error: \(error)."
                } else {
                    return "Can't get wistia subtitles for src: \(src)."
                }
            }
        }
    }
}
