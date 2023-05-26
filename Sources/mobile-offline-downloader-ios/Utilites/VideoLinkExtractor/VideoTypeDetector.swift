import Foundation

struct VideoTypeDetector {
    enum VideoType: String {
        case hapyak
        case wistia
        case vimeo
        case video
        case panopto
        case soapbox
        case unknown
        case youtube
        case eco
    }

    var link: String

    var url: URL {
        URL(string: link.lowercased()) ?? .empty
    }

    var host: String {
        url.host ?? ""
    }

    var type: VideoType {
        let turples: [(type: VideoType, value: Bool)] = [
            (.hapyak, isHapyak),
            (.wistia, isWistia),
            (.vimeo, isVimeo),
            (.youtube, isYoutube),
            (.video, isVideo),
            (.eco, isEco)
        ]

        return turples.first { $0.value }?.type ?? .unknown
    }

    var isYoutube: Bool {
        let youtubeDomains: [String] = ["youtube.com", "youtu.be"]
        return !youtubeDomains.filter { host.lowercased().contains($0) }.isEmpty
    }

    var isVideo: Bool {
        url.absoluteString.contains(".mp4") || url.absoluteString.contains(".mov")
    }

    var isWistia: Bool {
        host.contains("wistia")
    }

    var isVimeo: Bool {
        host.contains("vimeo")
    }

    var isHapyak: Bool {
        host.contains("hapyak")
    }

    var isEco: Bool {
        host.contains("helloeko")
    }
}

extension URL {
    static var empty: URL {
        URL(fileURLWithPath: "")
    }
}
