import Foundation
import SwiftUI

/// 「とうろく」モードの制御。子の声を録音し、保護者が意味を付けて辞書に保存する。
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

    private let store: PhraseStore
    private let recorder: AudioRecorder
    private let recognizer = SpeechRecognizer()

    init(store: PhraseStore) {
        self.store = store
        self.recorder = AudioRecorder(directory: store.recordingsDirectory)
    }

    var isRecording: Bool { phase == .recording }
    var canSave: Bool {
        audioFileName != nil && !meaning.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

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
        _ = await recognizer.requestAuthorization()
        do {
            audioFileName = try recorder.startRecording()
            roughTranscript = ""
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
        // ラフな読みは任意（取得できなくても登録は可能）
        roughTranscript = (try? await recognizer.transcribe(fileURL: url)) ?? ""
        phase = .ready
    }

    func playback() {
        // 確認用に「聞こえ方」ではなく入力中の意味を読み上げる（発音見本）
        let text = meaning.trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.isEmpty { EchoSpeaker.shared.speak(text) }
    }

    func save() {
        guard let fileName = audioFileName, canSave else { return }
        store.addPhrase(meaning: meaning,
                        audioFileName: fileName,
                        roughTranscript: roughTranscript)
        // 次の登録へ
        meaning = ""
        roughTranscript = ""
        audioFileName = nil
        phase = .idle
    }
}
