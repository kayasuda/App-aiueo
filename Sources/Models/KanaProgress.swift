import Foundation

struct KanaProgress: Codable, Hashable {
    let kana: String
    var shownCount: Int
    var quizCorrectCount: Int
    var quizWrongCount: Int
    var lastStudiedAt: Date?

    var accuracy: Double {
        let total = quizCorrectCount + quizWrongCount
        guard total > 0 else { return 0 }
        return Double(quizCorrectCount) / Double(total)
    }
}

