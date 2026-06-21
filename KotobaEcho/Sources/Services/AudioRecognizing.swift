import Foundation

/// 音声認識の N-best 候補（テキストと確信度）。
struct SpeechCandidate: Codable, Hashable {
    var text: String
    var confidence: Double
}

/// 録音の認識結果。
/// - candidates: 認識器が返した N-best のテキスト候補
/// - embedding: 波形から得た音響埋め込み（声紋的な特徴ベクトル）。
///   その子の発話どうしを直接照合するための主信号。取得できなければ nil。
struct AudioRecognition {
    var candidates: [SpeechCandidate]
    var embedding: [Float]?

    var bestText: String { candidates.first?.text ?? "" }
}

/// 録音ファイルを認識するサービスの抽象。
/// 端末内認識（SFSpeechRecognizer）とクラウド音声モデルを差し替え可能にする。
protocol AudioRecognizing {
    func recognize(fileURL: URL) async throws -> AudioRecognition
}
