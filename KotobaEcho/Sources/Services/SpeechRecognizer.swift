import Foundation
import Speech

/// 端末内の音声認識（SFSpeechRecognizer）。波形を端末外へ出さないフォールバック。
///
/// 構音障害の発話は汎用認識器では正確に書き起こせないため、得られる候補は
/// あくまで弱いヒント。音響埋め込みは取得できない（embedding は nil）。
/// 高精度を求める場合は CloudSpeechRecognizer（波形を音声モデルへ送信）を使う。
final class OnDeviceSpeechRecognizer: AudioRecognizing {

    enum RecognizerError: LocalizedError {
        case notAuthorized
        case unavailable
        case noResult

        var errorDescription: String? {
            switch self {
            case .notAuthorized: return "音声認識の利用が許可されていません。"
            case .unavailable: return "音声認識が利用できません。"
            case .noResult: return "音声を認識できませんでした。"
            }
        }
    }

    private let recognizer: SFSpeechRecognizer?

    init(locale: Locale = Locale(identifier: "ja-JP")) {
        self.recognizer = SFSpeechRecognizer(locale: locale)
    }

    static func requestAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    func recognize(fileURL: URL) async throws -> AudioRecognition {
        guard SFSpeechRecognizer.authorizationStatus() == .authorized else {
            throw RecognizerError.notAuthorized
        }
        guard let recognizer, recognizer.isAvailable else {
            throw RecognizerError.unavailable
        }

        let request = SFSpeechURLRecognitionRequest(url: fileURL)
        request.shouldReportPartialResults = false
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }

        let text: String = try await withCheckedThrowingContinuation { continuation in
            var hasResumed = false
            recognizer.recognitionTask(with: request) { result, error in
                if let error {
                    if !hasResumed { hasResumed = true; continuation.resume(throwing: error) }
                    return
                }
                guard let result, result.isFinal else { return }
                let best = result.bestTranscription.formattedString
                if !hasResumed {
                    hasResumed = true
                    if best.isEmpty {
                        continuation.resume(throwing: RecognizerError.noResult)
                    } else {
                        continuation.resume(returning: best)
                    }
                }
            }
        }

        return AudioRecognition(
            candidates: [SpeechCandidate(text: text, confidence: 0.3)],
            embedding: nil
        )
    }
}
