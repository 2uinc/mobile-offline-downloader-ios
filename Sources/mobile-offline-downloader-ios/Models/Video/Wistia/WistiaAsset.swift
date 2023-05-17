struct WistiaAsset: Codable {
    let type, slug, displayName: String
    let width, height, size, bitrate: Int?
    let assetPublic: Bool
    let status: Int
    let url: String
    let createdAt: Int
    let container, codec, ext: String?
    let segmentDuration: Int?

    enum CodingKeys: String, CodingKey {
        case type, slug
        case displayName = "display_name"
        case width, height, size, bitrate
        case assetPublic = "public"
        case status, url
        case createdAt = "created_at"
        case container, codec, ext
        case segmentDuration = "segment_duration"
    }
}
