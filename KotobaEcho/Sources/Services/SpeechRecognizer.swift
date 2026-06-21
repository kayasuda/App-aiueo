import Foundation
import Speech

/// 録音済みファイルから「ラフな読み」を取り出す。
///
/// 構音障害の発話を正確に書き起こすのは難しいため、ここで得られるのは
/// あくまで不正確な音のテキスト化（= 親が文脈推論する前の「聞こえた音」に相当）。
/// その不正確さを ClaudeInterpreter が文脈で補正する。
///
/// プライバシー配慮として、可能な端末では `requiresOnDeviceRecognition` を有効にし、
/// 音声をクラウド音声認識へ送らない。
final class SpeechRecognizer {

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

    /// 音声認識の利用許可をリクエスト。
    func requestAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    /// ファイルを認識して「ラフな読み」を返す。
    func transcribe(fileURL: URL) async throws -> String {
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

        return try await withCheckedThrowingContinuation { continuation in
            // 多重 resume を防ぐためのガード
            var hasResumed = false
            recognizer.recognitionTask(with: request) { result, error in
                if let error {
                    if !hasResumed { hasResumed = true; continuation.resume(throwing: error) }
                    return
                }
                guard let result, result.isFinal else { return }
                let text = result.bestTranscription.formattedString
                if !hasResumed {
                    hasResumed = true
                    if text.isEmpty {
                        continuation.resume(throwing: RecognizerError.noResult)
                    } else {
                        continuation.resume(returning: text)
                    }
                }
            }
        }
    }
}
