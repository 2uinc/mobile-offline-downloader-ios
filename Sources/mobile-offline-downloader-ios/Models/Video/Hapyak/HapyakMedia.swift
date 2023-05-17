struct HapyakMedia: Codable {
    let assets: [HapyakAsset]
    let type, mediaType: String
    let status: Int
    let name: String
    let duration: Double
    let createdAt: Int
    let hashedId: String?
}
