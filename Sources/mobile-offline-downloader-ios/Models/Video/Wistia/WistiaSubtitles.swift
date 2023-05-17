import Foundation

struct WistiaSubtitles: Codable {
    let captions: [WistiaCaption]
    let preferredLanguages: [String]

    enum CodingKeys: String, CodingKey {
        case captions
        case preferredLanguages = "preferred_languages"
    }
}

struct WistiaCaption: Codable {
    let id: Int
    let language, englishName, nativeName: String
    let rightToLeft: Bool
    let hash: WistiaHash?
    let key: String

    enum CodingKeys: String, CodingKey {
        case id, language
        case englishName = "english_name"
        case nativeName = "native_name"
        case rightToLeft = "right_to_left"
        case hash, key
    }
}

struct WistiaHash: Codable {
    let lines: [WistiaLine]
}

struct WistiaLine: Codable {
    let start, end: Double
    let text: [String]
}
