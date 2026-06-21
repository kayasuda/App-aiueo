import Foundation

/// 文脈推論サービスの抽象。テスト・モック・プロキシ差し替えを容易にする。
protocol ClaudeInterpreting {
    /// - Parameters:
    ///   - roughTranscript: 音声認識で得た不正確な読み
    ///   - knownPhrases: その子の登録フレーズ辞書
    ///   - recentTurns: 直近の会話履歴（文脈）
    ///   - childName: 子どもの呼び名（任意のヒント）
    func interpret(roughTranscript: String,
                   knownPhrases: [Phrase],
                   recentTurns: [ConversationTurn],
                   childName: String) async throws -> MatchCandidate
}

/// Anthropic Messages API（`claude-opus-4-8`）を生HTTPで呼び出す実装。
///
/// 「保護者が前後の文脈から我が子の発音を推測する」プロセスをLLMに代行させる。
/// クラウドへ送るのは音声波形ではなく、テキスト（ラフな読み・文脈・登録フレーズ）のみ。
final class ClaudeInterpreter: ClaudeInterpreting {

    enum InterpreterError: LocalizedError {
        case missingAPIKey
        case badURL
        case http(status: Int, body: String)
        case refusal
        case emptyResponse
        case decoding(String)

        var errorDescription: String? {
            switch self {
            case .missingAPIKey: return "APIキーが設定されていません。"
            case .badURL: return "APIのURLが不正です。"
            case .http(let status, _): return "サーバーエラー（HTTP \(status)）。"
            case .refusal: return "AIが応答を拒否しました。"
            case .emptyResponse: return "AIから空の応答が返りました。"
            case .decoding(let detail): return "応答の解析に失敗しました: \(detail)"
            }
        }
    }

    private let apiKey: String
    private let baseURL: String
    private let model: String
    private let session: URLSession

    /// - Parameter apiKey: プロキシ経由なら空文字でも可（プロキシ側で付与）。
    init(apiKey: String,
         baseURL: String = "https://api.anthropic.com",
         model: String = "claude-opus-4-8",
         session: URLSession = .shared) {
        self.apiKey = apiKey
        self.baseURL = baseURL
        self.model = model
        self.session = session
    }

    func interpret(roughTranscript: String,
                   knownPhrases: [Phrase],
                   recentTurns: [ConversationTurn],
                   childName: String) async throws -> MatchCandidate {

        guard let url = URL(string: baseURL.trimmingCharacters(in: .whitespaces) + "/v1/messages") else {
            throw InterpreterError.badURL
        }

        let body = makeRequestBody(roughTranscript: roughTranscript,
                                   knownPhrases: knownPhrases,
                                   recentTurns: recentTurns,
                                   childName: childName)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        // 直叩き時のみ x-api-key を付与。プロキシ経由ならキーは空でよい。
        if !apiKey.isEmpty {
            request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw InterpreterError.emptyResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            let bodyText = String(data: data, encoding: .utf8) ?? ""
            throw InterpreterError.http(status: http.statusCode, body: bodyText)
        }

        return try parseResponse(data: data, knownPhrases: knownPhrases)
    }

    // MARK: - リクエスト組み立て

    private func makeRequestBody(roughTranscript: String,
                                 knownPhrases: [Phrase],
                                 recentTurns: [ConversationTurn],
                                 childName: String) -> [String: Any] {

        let system = """
        あなたは構音障害のある子どもの発話を支援するアシスタントです。
        保護者が「前後の文脈」から我が子の不明瞭な発音を聞き取れるようになるのと同じように、
        あなたも文脈と、その子専用に登録されたフレーズ辞書を手がかりに、
        子どもが本当に言いたかった日本語を推定します。

        ルール:
        - まず登録フレーズ辞書（その子の過去の発話例）と照合し、近いものがあればそれを優先する。
        - 直近の会話の流れ（文脈）を重視する。
        - 確信が持てないときは confidence を低くし、最も自然な推定を返す。
        - 出力は子どもがそのまま聞いて学べる、正しく自然な日本語にする。
        - 推定はスキーマに従ったJSONのみで返す。
        """

        // 登録フレーズ辞書をテキスト化（音声波形は送らない）
        let phraseLines = knownPhrases.map { phrase -> String in
            let rough = phrase.recordings.map { $0.roughTranscript }
                .filter { !$0.isEmpty }
                .joined(separator: " / ")
            return "- id=\(phrase.id.uuidString) 意味=「\(phrase.meaning)」 これまでの聞こえ方=[\(rough)]"
        }
        let phraseBlock = phraseLines.isEmpty ? "（まだ登録フレーズはありません）" : phraseLines.joined(separator: "\n")

        // 直近の会話履歴
        let contextLines = recentTurns.suffix(8).map { "\($0.speaker.label): \($0.text)" }
        let contextBlock = contextLines.isEmpty ? "（直前の会話はありません）" : contextLines.joined(separator: "\n")

        let childHint = childName.isEmpty ? "" : "子どもの呼び名: \(childName)\n"

        let userText = """
        \(childHint)直近の会話（文脈）:
        \(contextBlock)

        その子の登録フレーズ辞書:
        \(phraseBlock)

        今、子どもが何か言いました。音声認識で聞こえた不正確な読みはこれです:
        「\(roughTranscript)」

        この子が本当に言いたかった言葉を推定してください。
        辞書のフレーズに一致するなら matched_phrase_id にそのidを入れ is_known を true に、
        新しい言い回しなら matched_phrase_id を空文字 "" にして is_known を false にしてください。
        note には推定の根拠を短く書いてください（なければ空文字）。
        """

        let schema: [String: Any] = [
            "type": "object",
            "properties": [
                "intended_text": ["type": "string"],
                // 該当なしは空文字 "" とする（nullable union を避け、structured outputs の安全な範囲に収める）
                "matched_phrase_id": ["type": "string"],
                "confidence": ["type": "number"],
                "is_known": ["type": "boolean"],
                "note": ["type": "string"]
            ],
            "required": ["intended_text", "matched_phrase_id", "confidence", "is_known", "note"],
            "additionalProperties": false
        ]

        return [
            "model": model,
            "max_tokens": 1024,
            "system": system,
            "output_config": [
                "format": [
                    "type": "json_schema",
                    "schema": schema
                ]
            ],
            "messages": [
                ["role": "user", "content": userText]
            ]
        ]
    }

    // MARK: - レスポンス解析

    private struct MessagesResponse: Decodable {
        struct ContentBlock: Decodable {
            let type: String
            let text: String?
        }
        let content: [ContentBlock]
        let stop_reason: String?
    }

    private struct StructuredOutput: Decodable {
        let intended_text: String
        let matched_phrase_id: String
        let confidence: Double
        let is_known: Bool
        let note: String
    }

    private func parseResponse(data: Data, knownPhrases: [Phrase]) throws -> MatchCandidate {
        let decoder = JSONDecoder()
        let envelope: MessagesResponse
        do {
            envelope = try decoder.decode(MessagesResponse.self, from: data)
        } catch {
            throw InterpreterError.decoding(error.localizedDescription)
        }

        if envelope.stop_reason == "refusal" {
            throw InterpreterError.refusal
        }

        // output_config.format により最初の text ブロックが有効なJSON
        guard let jsonText = envelope.content.first(where: { $0.type == "text" })?.text,
              let jsonData = jsonText.data(using: .utf8) else {
            throw InterpreterError.emptyResponse
        }

        let out: StructuredOutput
        do {
            out = try decoder.decode(StructuredOutput.self, from: jsonData)
        } catch {
            throw InterpreterError.decoding(error.localizedDescription)
        }

        // 返ってきた matched_phrase_id が実在するフレーズか検証（空文字や不明IDは nil 扱い）
        let matchedId: UUID? = UUID(uuidString: out.matched_phrase_id)
            .flatMap { id in knownPhrases.contains(where: { $0.id == id }) ? id : nil }

        let note = out.note.trimmingCharacters(in: .whitespacesAndNewlines)

        return MatchCandidate(
            intendedText: out.intended_text,
            matchedPhraseId: matchedId,
            confidence: min(max(out.confidence, 0), 1),
            isKnown: out.is_known,
            note: note.isEmpty ? nil : note
        )
    }
}
