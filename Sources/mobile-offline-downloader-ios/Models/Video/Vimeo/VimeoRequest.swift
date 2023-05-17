import Foundation
struct VimeoRequest: Codable {
    let files: VimeoFiles
    let textTracks: [VimeoTrack]?

    enum CodingKeys: String, CodingKey {
        case files
        case textTracks = "text_tracks"
    }
}

struct VimeoTrack: Codable {
    let lang: String
    let url: String
    let label: String
    let kind: String
}
