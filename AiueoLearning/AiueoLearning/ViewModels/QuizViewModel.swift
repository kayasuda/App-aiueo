import Foundation
import Combine

struct QuizQuestion {
    let kanaPrompt: String
    let choices: [String]
    let correctKana: String
    let mode: QuizMode
}

@MainActor
final class QuizViewModel: ObservableObject {
    @Published private(set) var questions: [QuizQuestion] = []
    @Published private(set) var currentIndex: Int = 0
    @Published private(set) var correctCount: Int = 0
    @Published private(set) var isCompleted: Bool = false
    @Published var selectedChoice: String?
    @Published var isCurrentAnswerCorrect: Bool?

    let questionCount: Int
    let mode: QuizMode
    let startedAt: Date

    init(questionCount: Int = 10, mode: QuizMode) {
        self.questionCount = questionCount
        self.mode = mode
        self.startedAt = Date()
        self.questions = Self.generateQuestions(count: questionCount, mode: mode)
    }

    var currentQuestion: QuizQuestion? {
        guard currentIndex < questions.count else { return nil }
        return questions[currentIndex]
    }

    var progressText: String {
        "\(min(currentIndex + 1, questionCount))/\(questionCount)"
    }

    func select(_ choice: String) {
        guard isCurrentAnswerCorrect == nil, let current = currentQuestion else { return }
        selectedChoice = choice
        let correct = (choice == current.correctKana)
        isCurrentAnswerCorrect = correct
        if correct {
            correctCount += 1
        }
    }

    func advance() {
        guard isCurrentAnswerCorrect != nil else { return }
        selectedChoice = nil
        isCurrentAnswerCorrect = nil

        if currentIndex + 1 >= questionCount {
            isCompleted = true
        } else {
            currentIndex += 1
        }
    }

    static func generateQuestions(count: Int, mode: QuizMode) -> [QuizQuestion] {
        var rng = SystemRandomNumberGenerator()
        let kana = KanaCatalog.hiragana
        var result: [QuizQuestion] = []

        for _ in 0..<count {
            let correct = kana.randomElement(using: &rng) ?? "あ"
            let wrongPool = kana.filter { $0 != correct }.shuffled(using: &rng)
            let wrongChoices = Array(wrongPool.prefix(2))
            let choices = ([correct] + wrongChoices).shuffled(using: &rng)
            result.append(QuizQuestion(kanaPrompt: correct, choices: choices, correctKana: correct, mode: mode))
        }
        return result
    }
}
