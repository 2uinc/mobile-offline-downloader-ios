import Foundation
import SwiftSoup
protocol OfflineHTMLLinksExtractorProtocol {}
extension OfflineHTMLLinksExtractorProtocol {
    var sourceAttributes: [String] {
        ["src", "href", "poster"]
    }

    var sourceTags: [String] {
        ["img", "link", "script", "video", "audio", "iframe", "source", "track", "a"]
    }

    var documentExtensions: [String] {
        ["xls", "xlsx", "pdf", "ppt", "pptx", "txt", "doc", "docx",
        "rtf", "key", "numbers", "pages", "png", "gif", "jpg", "jpeg", "mp4", "mp3", "bin"]
    }

}
