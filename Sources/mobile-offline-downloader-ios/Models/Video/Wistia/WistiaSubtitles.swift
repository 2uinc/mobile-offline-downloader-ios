import Foundation

struct WistiaSubtitles: Codable {
    let captions: [WistiaCaption]

    enum CodingKeys: String, CodingKey {
        case captions
    }
}

struct WistiaCaption: Codable {
    let language, englishName, nativeName: String
    let rightToLeft: Bool
    let hash: WistiaHash?
    let key: String

    enum CodingKeys: String, CodingKey {
        case language
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
