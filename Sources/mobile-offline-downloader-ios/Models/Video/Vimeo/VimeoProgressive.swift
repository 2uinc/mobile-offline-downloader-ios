import Foundation
struct VimeoProgressive: Codable {
    let profile: String
    let width: Int
    let mime: String
    let fps: Double
    let url: String
    let cdn, quality, id, origin: String
    let height: Int
}
