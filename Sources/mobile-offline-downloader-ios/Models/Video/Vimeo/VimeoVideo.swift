import Foundation
struct VimeoVideo: Codable {
    let request: VimeoRequest
    let video: VimeoVideoObject
    let playerURL: String

    enum CodingKeys: String, CodingKey {
        case request
        case video
        case playerURL = "player_url"
    }
}

struct VimeoVideoObject: Codable {
    let thumbs: [String: String]
}
