import Foundation

/// クラウドの音声モデルに**波形そのもの**を送って認識するサービス。
///
/// Claude は音声入力に対応しないため、波形はこの別エンドポイントへ送る。
/// エンドポイントは差し替え可能（汎用ASR・独自の個人特化モデル・自前プロキシ等）。
///
/// 期待するHTTP契約（自前サーバ/プロキシ側で実装する）:
///   POST {baseURL}/recognize
///   req : { "audio_base64": "<m4aのbase64>", "format": "m4a", "locale": "ja-JP" }
///   res : { "candidates": [ {"text": "...", "confidence": 0.0-1.0}, ... ],
///           "embedding": [Float]   // 波形由来の音響埋め込み（任意）
///         }
///
/// `embedding` を返せば、その子の登録サンプルとの波形照合（AcousticMatcher）が効く。
/// 返せない場合でも candidates のテキストだけで動作する。
final class CloudSpeechRecognizer: AudioRecognizing {

    enum SpeechError: LocalizedError {
        case badURL
        case http(status: Int, body: String)
        case decoding(String)

        var errorDescription: String? {
            switch self {
            case .badURL: return "音声認識エンドポイントのURLが不正です。"
            case .http(let status, _): return "音声認識サーバーエラー（HTTP \(status)）。"
            case .decoding(let detail): return "音声認識結果の解析に失敗しました: \(detail)"
            }
        }
    }

    private let baseURL: String
    private let apiKey: String
    private let locale: String
    private let session: URLSession

    init(baseURL: String,
         apiKey: String = "",
         locale: String = "ja-JP",
         session: URLSession = .shared) {
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.locale = locale
        self.session = session
    }

    func recognize(fileURL: URL) async throws -> AudioRecognition {
        guard let url = URL(string: baseURL.trimmingCharacters(in: .whitespaces) + "/recognize") else {
            throw SpeechError.badURL
        }

        let audioData = try Data(contentsOf: fileURL)
        let body: [String: Any] = [
            "audio_base64": audioData.base64EncodedString(),
            "format": fileURL.pathExtension.isEmpty ? "m4a" : fileURL.pathExtension,
            "locale": locale
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        if !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "authorization")
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw SpeechError.http(status: -1, body: "")
        }
        guard (200..<300).contains(http.statusCode) else {
            throw SpeechError.http(status: http.statusCode,
                                   body: String(data: data, encoding: .utf8) ?? "")
        }

        do {
            let decoded = try JSONDecoder().decode(Response.self, from: data)
            let candidates = decoded.candidates.map {
                SpeechCandidate(text: $0.text, confidence: $0.confidence ?? 0.5)
            }
            return AudioRecognition(candidates: candidates, embedding: decoded.embedding)
        } catch {
            throw SpeechError.decoding(error.localizedDescription)
        }
    }

    // MARK: - レスポンス契約

    private struct Response: Decodable {
        struct Candidate: Decodable {
            let text: String
            let confidence: Double?
        }
        let candidates: [Candidate]
        let embedding: [Float]?
    }
}
