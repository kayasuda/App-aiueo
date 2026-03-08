import Foundation

struct QuizSessionResult: Codable, Identifiable {
    let id: UUID
    let startedAt: Date
    let endedAt: Date
    let questionCount: Int
    let correctCount: Int
    let mode: QuizMode
}

