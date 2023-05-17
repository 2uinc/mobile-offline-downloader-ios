struct WistiaVideo: Codable {
    let assets: [WistiaAsset]
    let type: String
    let mediaType: String
    let name: String
    let options: WistiaOptions
    let hashedId: String

    enum CodingKeys: String, CodingKey {
        case assets, type, mediaType, name
        case options = "embed_options"
        case hashedId
    }
}

struct WistiaOptions: Codable {
    let playerColor: String
}
