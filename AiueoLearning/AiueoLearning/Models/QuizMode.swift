import Foundation

enum QuizMode: String, Codable, CaseIterable {
    case audioToKana
    case kanaToAudio

    var title: String {
        switch self {
        case .audioToKana:
            return "おとを きいて もじを えらぼう"
        case .kanaToAudio:
            return "もじを みて おとを えらぼう"
        }
    }
}

