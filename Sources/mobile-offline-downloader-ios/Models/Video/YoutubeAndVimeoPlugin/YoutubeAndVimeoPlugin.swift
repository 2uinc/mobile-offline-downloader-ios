import Foundation
struct YoutubeAndVimeoPlugin: Codable {
    let techOrder: [String]
    let sources: [YoutubeAndVimeoPluginSource]
}

struct YoutubeAndVimeoPluginSource: Codable {
    let type: String
    let src: String
}
