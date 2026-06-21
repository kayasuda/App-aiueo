import Foundation
import SwiftUI

/// アプリ全体の状態管理と永続化の中核。
/// フレーズ辞書・会話履歴・設定を保持し、音声ファイルのディレクトリも管理する。
@MainActor
final class PhraseStore: ObservableObject {
    @Published private(set) var phrases: [Phrase] = []
    @Published private(set) var recentTurns: [ConversationTurn] = []
    @Published var config: AppConfig = .default {
        didSet { saveConfig() }
    }

    /// 録音ファイルを置くディレクトリ。
    let recordingsDirectory: URL

    private let phrasesURL: URL
    private let configKey = "kotobaecho.config.v1"
    private let apiKeyKeychainKey = "anthropic.api.key"
    private let maxTurns = 40

    init() {
        let fm = FileManager.default
        let base = (try? fm.url(for: .applicationSupportDirectory,
                                in: .userDomainMask,
                                appropriateFor: nil,
                                create: true)) ?? fm.temporaryDirectory
        let root = base.appendingPathComponent("KotobaEcho", isDirectory: true)
        let recordings = root.appendingPathComponent("Recordings", isDirectory: true)
        try? fm.createDirectory(at: recordings, withIntermediateDirectories: true)

        self.recordingsDirectory = recordings
        self.phrasesURL = root.appendingPathComponent("phrases.json")

        loadConfig()
        loadPhrases()
    }

    // MARK: - APIキー

    var apiKey: String {
        get { KeychainStore.get(apiKeyKeychainKey) ?? "" }
        set { KeychainStore.set(newValue, for: apiKeyKeychainKey) }
    }

    // MARK: - フレーズ辞書

    /// 新しいフレーズ（意味＋音声サンプル1件）を登録。
    func addPhrase(meaning: String, audioFileName: String, roughTranscript: String) {
        let recording = PhraseRecording(audioFileName: audioFileName, roughTranscript: roughTranscript)
        let trimmed = meaning.trimmingCharacters(in: .whitespacesAndNewlines)

        if let index = phrases.firstIndex(where: { $0.meaning == trimmed }) {
            // 同じ意味が既にあれば音声サンプルを追加
            phrases[index].recordings.append(recording)
            phrases[index].updatedAt = Date()
        } else {
            let phrase = Phrase(meaning: trimmed, recordings: [recording])
            phrases.append(phrase)
        }
        savePhrases()
    }

    /// 既存フレーズに音声サンプルを追加（訂正学習）。
    func addRecording(to phraseId: UUID, audioFileName: String, roughTranscript: String) {
        guard let index = phrases.firstIndex(where: { $0.id == phraseId }) else { return }
        phrases[index].recordings.append(
            PhraseRecording(audioFileName: audioFileName, roughTranscript: roughTranscript)
        )
        phrases[index].updatedAt = Date()
        savePhrases()
    }

    /// 推定で選ばれたフレーズの利用回数を加算。
    func markMatched(_ phraseId: UUID) {
        guard let index = phrases.firstIndex(where: { $0.id == phraseId }) else { return }
        phrases[index].timesMatched += 1
        savePhrases()
    }

    func deletePhrase(_ phraseId: UUID) {
        guard let phrase = phrases.first(where: { $0.id == phraseId }) else { return }
        for recording in phrase.recordings {
            try? FileManager.default.removeItem(at: recordingsDirectory.appendingPathComponent(recording.audioFileName))
        }
        phrases.removeAll { $0.id == phraseId }
        savePhrases()
    }

    // MARK: - 会話履歴（文脈）

    func appendTurn(speaker: Speaker, text: String) {
        recentTurns.append(ConversationTurn(speaker: speaker, text: text))
        if recentTurns.count > maxTurns {
            recentTurns.removeFirst(recentTurns.count - maxTurns)
        }
    }

    func clearConversation() {
        recentTurns.removeAll()
    }

    // MARK: - 全データ削除（プライバシー）

    func deleteAllData() {
        for phrase in phrases {
            for recording in phrase.recordings {
                try? FileManager.default.removeItem(at: recordingsDirectory.appendingPathComponent(recording.audioFileName))
            }
        }
        phrases.removeAll()
        recentTurns.removeAll()
        savePhrases()
    }

    // MARK: - 永続化

    private func loadPhrases() {
        guard let data = try? Data(contentsOf: phrasesURL),
              let decoded = try? JSONDecoder().decode([Phrase].self, from: data) else { return }
        phrases = decoded
    }

    private func savePhrases() {
        guard let data = try? JSONEncoder().encode(phrases) else { return }
        try? data.write(to: phrasesURL, options: .atomic)
    }

    private func loadConfig() {
        guard let data = UserDefaults.standard.data(forKey: configKey),
              let decoded = try? JSONDecoder().decode(AppConfig.self, from: data) else { return }
        config = decoded
    }

    private func saveConfig() {
        guard let data = try? JSONEncoder().encode(config) else { return }
        UserDefaults.standard.set(data, forKey: configKey)
    }
}
