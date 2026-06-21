import Foundation
import SwiftUI

/// 「きく」モードの制御。録音 → ラフな読み → 文脈推論 → 復唱、までを束ねる。
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
    /// 最後に録音したファイル名（訂正学習で再利用）
    @Published private(set) var lastAudioFileName: String?
    @Published private(set) var lastRoughTranscript: String = ""

    private let store: PhraseStore
    private let recorder: AudioRecorder
    private let recognizer = SpeechRecognizer()

    init(store: PhraseStore) {
        self.store = store
        self.recorder = AudioRecorder(directory: store.recordingsDirectory)
    }

    var isRecording: Bool { phase == .recording }

    // MARK: - 録音トグル

    func toggleRecording() async {
        if isRecording {
            await finishRecording()
        } else {
            await beginRecording()
        }
    }

    private func beginRecording() async {
        guard await recorder.requestPermission() else {
            phase = .error("マイクの利用が許可されていません。")
            return
        }
        guard await recognizer.requestAuthorization() else {
            phase = .error("音声認識の利用が許可されていません。")
            return
        }
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
            let rough = try await recognizer.transcribe(fileURL: url)
            lastRoughTranscript = rough

            let interpreter = makeInterpreter()
            let result = try await interpreter.interpret(
                roughTranscript: rough,
                knownPhrases: store.phrases,
                recentTurns: store.recentTurns,
                childName: store.config.childName
            )

            candidate = result
            phase = .result

            // 確定テキストを文脈に追加し、正しい発音で復唱
            store.appendTurn(speaker: .child, text: result.intendedText)
            if let id = result.matchedPhraseId {
                store.markMatched(id)
            }
            EchoSpeaker.shared.speak(result.intendedText)

        } catch {
            phase = .error(error.localizedDescription)
        }
    }

    /// もう一度復唱。
    func repeatEcho() {
        if let text = candidate?.intendedText {
            EchoSpeaker.shared.speak(text)
        }
    }

    /// 保護者が訂正：正しい意味を辞書に学習させ、復唱し直す。
    func correct(to meaning: String) {
        guard let fileName = lastAudioFileName else { return }
        let trimmed = meaning.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        store.addPhrase(meaning: trimmed,
                        audioFileName: fileName,
                        roughTranscript: lastRoughTranscript)
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

    // MARK: - 推論器の選択

    private func makeInterpreter() -> ClaudeInterpreting {
        let config = store.config
        let key = store.apiKey
        // クラウド同意あり、かつキーまたはプロキシURLが使える場合のみクラウド
        let usingProxy = config.apiBaseURL != "https://api.anthropic.com"
        if config.cloudEnabled && (!key.isEmpty || usingProxy) {
            return ClaudeInterpreter(apiKey: key, baseURL: config.apiBaseURL, model: config.model)
        }
        return LocalInterpreter()
    }
}
