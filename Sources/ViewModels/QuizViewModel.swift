import Foundation

struct QuizQuestion {
    let kanaPrompt: String
    let choices: [String]
    let correctKana: String
    let mode: QuizMode
}

/// 1問ごとの回答ログ
struct AnswerLog {
    let questionIndex: Int
    let kana: String
    let isCorrect: Bool
    let responseTime: TimeInterval  // 問題表示から回答までの秒数
    let answeredAt: Date
}

@MainActor
final class QuizViewModel: ObservableObject {
    @Published private(set) var questions: [QuizQuestion] = []
    @Published private(set) var currentIndex: Int = 0
    @Published private(set) var correctCount: Int = 0
    @Published private(set) var isCompleted: Bool = false
    @Published var selectedChoice: String?
    @Published var isCurrentAnswerCorrect: Bool?

    /// 回答ログ（集中度判定に使用）
    @Published private(set) var answerLogs: [AnswerLog] = []

    let questionCount: Int
    let mode: QuizMode
    let startedAt: Date
    /// 現在の問題が表示された時刻
    private var questionShownAt: Date

    init(questionCount: Int = 5, mode: QuizMode) {
        self.questionCount = questionCount
        self.mode = mode
        self.startedAt = Date()
        self.questionShownAt = Date()
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

        let now = Date()
        let log = AnswerLog(
            questionIndex: currentIndex,
            kana: current.correctKana,
            isCorrect: correct,
            responseTime: now.timeIntervalSince(questionShownAt),
            answeredAt: now
        )
        answerLogs.append(log)
    }

    func advance() {
        guard isCurrentAnswerCorrect != nil else { return }
        selectedChoice = nil
        isCurrentAnswerCorrect = nil

        if currentIndex + 1 >= questionCount {
            isCompleted = true
        } else {
            currentIndex += 1
            questionShownAt = Date()
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

