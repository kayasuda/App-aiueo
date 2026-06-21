import Foundation
import SwiftUI

/// 「とうろく」モードの制御。子の声を録音し、波形（埋め込み）と意味を辞書に保存する。
@MainActor
final class RegisterViewModel: ObservableObject {

    enum Phase: Equatable {
        case idle
        case recording
        case transcribing
        case ready          // 録音済み・意味入力待ち
        case error(String)
    }

    @Published private(set) var phase: Phase = .idle
    @Published var meaning: String = ""
    @Published private(set) var roughTranscript: String = ""

    private var audioFileName: String?
    private var embedding: [Float]?

    private let store: PhraseStore
    private let recorder: AudioRecorder

    init(store: PhraseStore) {
        self.store = store
        self.recorder = AudioRecorder(directory: store.recordingsDirectory)
    }

    var isRecording: Bool { phase == .recording }
    var canSave: Bool {
        audioFileName != nil && !meaning.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func toggleRecording() async {
        if isRecording { await finishRecording() } else { await beginRecording() }
    }

    private func beginRecording() async {
        guard await recorder.requestPermission() else {
            phase = .error("マイクの利用が許可されていません。")
            return
        }
        _ = await OnDeviceSpeechRecognizer.requestAuthorization()
        do {
            audioFileName = try recorder.startRecording()
            roughTranscript = ""
            embedding = nil
            phase = .recording
        } catch {
            phase = .error("録音を開始できませんでした: \(error.localizedDescription)")
        }
    }

    private func finishRecording() async {
        recorder.stopRecording()
        phase = .transcribing

        guard let fileName = audioFileName else {
            phase = .error("録音ファイルが見つかりません。")
            return
        }
        let url = store.recordingsDirectory.appendingPathComponent(fileName)

        // 波形を認識し、聞こえ方テキストと音響埋め込みを取得（失敗しても登録は可能）
        if let recognition = try? await makeRecognizer().recognize(fileURL: url) {
            roughTranscript = recognition.bestText
            embedding = recognition.embedding
        }
        phase = .ready
    }

    func playback() {
        let text = meaning.trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.isEmpty { EchoSpeaker.shared.speak(text) }
    }

    func save() {
        guard let fileName = audioFileName, canSave else { return }
        store.addPhrase(meaning: meaning,
                        audioFileName: fileName,
                        roughTranscript: roughTranscript,
                        embedding: embedding)
        meaning = ""
        roughTranscript = ""
        audioFileName = nil
        embedding = nil
        phase = .idle
    }

    private func makeRecognizer() -> AudioRecognizing {
        let config = store.config
        if config.cloudEnabled && !config.speechBaseURL.trimmingCharacters(in: .whitespaces).isEmpty {
            return CloudSpeechRecognizer(baseURL: config.speechBaseURL, apiKey: store.speechAPIKey)
        }
        return OnDeviceSpeechRecognizer()
    }
}
