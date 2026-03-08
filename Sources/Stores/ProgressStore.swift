import Foundation

@MainActor
final class ProgressStore: ObservableObject {
    @Published var settings: AppSettings
    @Published private(set) var kanaProgress: [String: KanaProgress]
    @Published private(set) var sessionHistory: [QuizSessionResult]

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private let settingsKey = "app_settings_v1"
    private let progressKey = "kana_progress_v1"
    private let sessionKey = "quiz_session_v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.settings = AppSettings()
        self.kanaProgress = [:]
        self.sessionHistory = []
        load()
        bootstrapMissingKana()
    }

    func updateSettings(_ updater: (inout AppSettings) -> Void) {
        updater(&settings)
        saveSettings()
    }

    func recordStudy(kana: String, at date: Date = Date()) {
        guard var progress = kanaProgress[kana] else { return }
        progress.shownCount += 1
        progress.lastStudiedAt = date
        kanaProgress[kana] = progress
        saveProgress()
    }

    func recordQuizAnswer(kana: String, correct: Bool, at date: Date = Date()) {
        guard var progress = kanaProgress[kana] else { return }
        if correct {
            progress.quizCorrectCount += 1
        } else {
            progress.quizWrongCount += 1
        }
        progress.lastStudiedAt = date
        kanaProgress[kana] = progress
        saveProgress()
    }

    func saveSession(_ result: QuizSessionResult) {
        sessionHistory.insert(result, at: 0)
        if sessionHistory.count > 30 {
            sessionHistory = Array(sessionHistory.prefix(30))
        }
        saveSessions()
    }

    func progressList() -> [KanaProgress] {
        KanaCatalog.hiragana.compactMap { kanaProgress[$0] }
    }

    func dailySessionCount(on date: Date = Date(), calendar: Calendar = .current) -> Int {
        sessionHistory.filter { calendar.isDate($0.startedAt, inSameDayAs: date) }.count
    }

    func weakKana(threshold: Double = 0.6) -> [KanaProgress] {
        progressList()
            .filter { ($0.quizCorrectCount + $0.quizWrongCount) > 0 && $0.accuracy < threshold }
            .sorted { $0.accuracy < $1.accuracy }
    }

    private func load() {
        if let data = defaults.data(forKey: settingsKey),
           let saved = try? decoder.decode(AppSettings.self, from: data) {
            settings = saved
        }

        if let data = defaults.data(forKey: progressKey),
           let saved = try? decoder.decode([String: KanaProgress].self, from: data) {
            kanaProgress = saved
        }

        if let data = defaults.data(forKey: sessionKey),
           let saved = try? decoder.decode([QuizSessionResult].self, from: data) {
            sessionHistory = saved
        }
    }

    private func bootstrapMissingKana() {
        for kana in KanaCatalog.hiragana where kanaProgress[kana] == nil {
            kanaProgress[kana] = KanaProgress(
                kana: kana,
                shownCount: 0,
                quizCorrectCount: 0,
                quizWrongCount: 0,
                lastStudiedAt: nil
            )
        }
        saveProgress()
    }

    private func saveSettings() {
        if let data = try? encoder.encode(settings) {
            defaults.set(data, forKey: settingsKey)
        }
    }

    private func saveProgress() {
        if let data = try? encoder.encode(kanaProgress) {
            defaults.set(data, forKey: progressKey)
        }
    }

    private func saveSessions() {
        if let data = try? encoder.encode(sessionHistory) {
            defaults.set(data, forKey: sessionKey)
        }
    }
}

