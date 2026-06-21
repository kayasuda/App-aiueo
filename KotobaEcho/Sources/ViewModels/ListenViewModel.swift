import Foundation
import SwiftUI

/// 「きく」モードの制御。
/// 録音 → 波形を音声モデルで認識 → その子の登録サンプルと波形照合 → Claudeで文脈推論 → 復唱。
@MainActor
final class ListenViewModel: ObservableObject {

    enum Phase: Equatable {
        case idle
        case recording
        case thinking
        case result
        case error(String)
    }

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var candidate: MatchCandidate?

    private let store: PhraseStore
    private let recorder: AudioRecorder

    // 訂正学習で再利用するため、最後の発話の情報を保持
    private var lastAudioFileName: String?
    private var lastEmbedding: [Float]?
    private var lastRoughText: String = ""

    init(store: PhraseStore) {
        self.store = store
        self.recorder = AudioRecorder(directory: store.recordingsDirectory)
    }

    var isRecording: Bool { phase == .recording }

    func toggleRecording() async {
        if isRecording { await finishRecording() } else { await beginRecording() }
    }

    private func beginRecording() async {
        guard await recorder.requestPermission() else {
            phase = .error("マイクの利用が許可されていません。")
            return
        }
        // 端末内認識のフォールバックに備えて許可を取得
        _ = await OnDeviceSpeechRecognizer.requestAuthorization()

        candidate = nil
        do {
            lastAudioFileName = try recorder.startRecording()
            phase = .recording
        } catch {
            phase = .error("録音を開始できませんでした: \(error.localizedDescription)")
        }
    }

    private func finishRecording() async {
        recorder.stopRecording()
        phase = .thinking

        guard let fileName = lastAudioFileName else {
            phase = .error("録音ファイルが見つかりません。")
            return
        }
        let url = store.recordingsDirectory.appendingPathComponent(fileName)

        do {
            // 1. 波形を認識（クラウド音声モデル or 端末内）
            let recognition = try await makeRecognizer().recognize(fileURL: url)
            lastEmbedding = recognition.embedding
            lastRoughText = recognition.bestText

            // 2. その子の登録サンプルと波形照合
            let acousticMatches = AcousticMatcher.rank(
                query: recognition.embedding ?? [],
                phrases: store.phrases
            )

            // 3. 文脈推論で確定
            let result = try await makeInterpreter().interpret(
                transcriptCandidates: recognition.candidates,
                acousticMatches: acousticMatches,
                knownPhrases: store.phrases,
                recentTurns: store.recentTurns,
                childName: store.config.childName
            )

            candidate = result
            phase = .result

            store.appendTurn(speaker: .child, text: result.intendedText)
            if let id = result.matchedPhraseId { store.markMatched(id) }
            EchoSpeaker.shared.speak(result.intendedText)

        } catch {
            phase = .error(error.localizedDescription)
        }
    }

    func repeatEcho() {
        if let text = candidate?.intendedText { EchoSpeaker.shared.speak(text) }
    }

    /// 保護者が訂正：今の発話（波形・埋め込み）を正しい意味に紐づけて学習させる。
    func correct(to meaning: String) {
        guard let fileName = lastAudioFileName else { return }
        let trimmed = meaning.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        store.addPhrase(meaning: trimmed,
                        audioFileName: fileName,
                        roughTranscript: lastRoughText,
                        embedding: lastEmbedding)
        store.appendTurn(speaker: .parent, text: "（訂正）\(trimmed)")

        candidate = MatchCandidate(intendedText: trimmed,
                                   matchedPhraseId: nil,
                                   confidence: 1.0,
                                   isKnown: true,
                                   note: "保護者が訂正")
        EchoSpeaker.shared.speak(trimmed)
    }

    func reset() {
        phase = .idle
        candidate = nil
    }

    // MARK: - 推論器・認識器の選択

    private func makeRecognizer() -> AudioRecognizing {
        let config = store.config
        if config.cloudEnabled && !config.speechBaseURL.trimmingCharacters(in: .whitespaces).isEmpty {
            return CloudSpeechRecognizer(baseURL: config.speechBaseURL, apiKey: store.speechAPIKey)
        }
        return OnDeviceSpeechRecognizer()
    }

    private func makeInterpreter() -> ClaudeInterpreting {
        let config = store.config
        let key = store.apiKey
        let usingProxy = config.apiBaseURL != "https://api.anthropic.com"
        if config.cloudEnabled && (!key.isEmpty || usingProxy) {
            return ClaudeInterpreter(apiKey: key, baseURL: config.apiBaseURL, model: config.model)
        }
        return LocalInterpreter()
    }
}
