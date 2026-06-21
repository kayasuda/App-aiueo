import Foundation

/// 文脈推論サービスの抽象。テスト・モック・プロキシ差し替えを容易にする。
///
/// 入力は「波形から得た情報」（音声モデルの N-best 候補と、その子の登録サンプルとの
/// 音響照合結果）＋ 会話文脈。出力は「言いたかった言葉」の確定。
protocol ClaudeInterpreting {
    func interpret(transcriptCandidates: [SpeechCandidate],
                   acousticMatches: [AcousticMatch],
                   knownPhrases: [Phrase],
                   recentTurns: [ConversationTurn],
                   childName: String) async throws -> MatchCandidate
}

/// Anthropic Messages API（`claude-opus-4-8`）を生HTTPで呼び出す実装。
///
/// 「保護者が前後の文脈から我が子の発音を推測する」プロセスをLLMに代行させる。
/// 波形は別の音声モデルが処理済みで、ここに渡るのはその出力（候補・音響照合）と文脈の
/// テキスト。Claude は音声非対応のため、音声波形そのものは渡さない。
final class ClaudeInterpreter: ClaudeInterpreting {

    enum InterpreterError: LocalizedError {
        case badURL
        case http(status: Int, body: String)
        case refusal
        case emptyResponse
        case decoding(String)

        var errorDescription: String? {
            switch self {
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

    init(apiKey: String,
         baseURL: String = "https://api.anthropic.com",
         model: String = "claude-opus-4-8",
         session: URLSession = .shared) {
        self.apiKey = apiKey
        self.baseURL = baseURL
        self.model = model
        self.session = session
    }

    func interpret(transcriptCandidates: [SpeechCandidate],
                   acousticMatches: [AcousticMatch],
                   knownPhrases: [Phrase],
                   recentTurns: [ConversationTurn],
                   childName: String) async throws -> MatchCandidate {

        guard let url = URL(string: baseURL.trimmingCharacters(in: .whitespaces) + "/v1/messages") else {
            throw InterpreterError.badURL
        }

        let body = makeRequestBody(transcriptCandidates: transcriptCandidates,
                                   acousticMatches: acousticMatches,
                                   knownPhrases: knownPhrases,
                                   recentTurns: recentTurns,
                                   childName: childName)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        if !apiKey.isEmpty {
            request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw InterpreterError.emptyResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            throw InterpreterError.http(status: http.statusCode,
                                        body: String(data: data, encoding: .utf8) ?? "")
        }

        return try parseResponse(data: data, knownPhrases: knownPhrases)
    }

    // MARK: - リクエスト組み立て

    private func makeRequestBody(transcriptCandidates: [SpeechCandidate],
                                 acousticMatches: [AcousticMatch],
                                 knownPhrases: [Phrase],
                                 recentTurns: [ConversationTurn],
                                 childName: String) -> [String: Any] {

        let system = """
        あなたは構音障害のある子どもの発話を支援するアシスタントです。
        保護者が「前後の文脈」から我が子の不明瞭な発音を聞き取れるようになるのと同じように、
        あなたも文脈・音声候補・音響照合を手がかりに、子どもが本当に言いたかった日本語を推定します。

        判断材料の信頼度の目安:
        - 音響照合（その子の過去の発話との波形の近さ）が最も信頼できる。スコアが高いフレーズを最優先する。
        - 音声候補（汎用認識のN-best）は不正確なことが多いので、補助的に使う。
        - 会話の流れ（文脈）で最も自然な解釈を選ぶ。
        - どれも確信が持てなければ confidence を低くし、最も自然な推定を返す。
        - 出力は子どもがそのまま聞いて学べる、正しく自然な日本語にする。
        """

        let acousticLines = acousticMatches.map {
            "- id=\($0.phraseId.uuidString) 意味=「\($0.meaning)」 波形の近さ=\(String(format: "%.2f", $0.score))"
        }
        let acousticBlock = acousticLines.isEmpty ? "（音響照合の候補なし）" : acousticLines.joined(separator: "\n")

        let transcriptLines = transcriptCandidates.prefix(5).map {
            "- 「\($0.text)」 (\(String(format: "%.2f", $0.confidence)))"
        }
        let transcriptBlock = transcriptLines.isEmpty ? "（音声候補なし）" : transcriptLines.joined(separator: "\n")

        let phraseLines = knownPhrases.map { phrase -> String in
            "- id=\(phrase.id.uuidString) 意味=「\(phrase.meaning)」 サンプル数=\(phrase.recordings.count)"
        }
        let phraseBlock = phraseLines.isEmpty ? "（まだ登録フレーズはありません）" : phraseLines.joined(separator: "\n")

        let contextLines = recentTurns.suffix(8).map { "\($0.speaker.label): \($0.text)" }
        let contextBlock = contextLines.isEmpty ? "（直前の会話はありません）" : contextLines.joined(separator: "\n")

        let childHint = childName.isEmpty ? "" : "子どもの呼び名: \(childName)\n"

        let userText = """
        \(childHint)直近の会話（文脈）:
        \(contextBlock)

        音響照合の上位候補（その子の過去の発話との波形の近さ。最も信頼できる手がかり）:
        \(acousticBlock)

        音声モデルのN-best候補（補助。不正確なことが多い）:
        \(transcriptBlock)

        その子の登録フレーズ辞書:
        \(phraseBlock)

        以上から、子どもが本当に言いたかった言葉を1つ推定してください。
        登録フレーズに一致するなら matched_phrase_id にそのidを入れ is_known を true に、
        新しい言い回しなら matched_phrase_id を空文字 "" にして is_known を false にしてください。
        note には推定の根拠を短く書いてください（なければ空文字）。
        """

        let schema: [String: Any] = [
            "type": "object",
            "properties": [
                "intended_text": ["type": "string"],
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
            "output_config": ["format": ["type": "json_schema", "schema": schema]],
            "messages": [["role": "user", "content": userText]]
        ]
    }

    // MARK: - レスポンス解析

    private struct MessagesResponse: Decodable {
        struct ContentBlock: Decodable { let type: String; let text: String? }
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
