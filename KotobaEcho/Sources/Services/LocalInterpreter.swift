import Foundation

/// クラウド未使用時のオフライン推定。登録フレーズの「聞こえ方」と
/// 今回のラフな読みを文字列の近さ（編集距離）で照合する単純版。
///
/// 文脈は使えないため精度は限定的だが、同意前でも最低限動く。
struct LocalInterpreter: ClaudeInterpreting {

    func interpret(roughTranscript: String,
                   knownPhrases: [Phrase],
                   recentTurns: [ConversationTurn],
                   childName: String) async throws -> MatchCandidate {

        let query = roughTranscript

        var best: (phrase: Phrase, score: Double)?
        for phrase in knownPhrases {
            for recording in phrase.recordings {
                let score = similarity(query, recording.roughTranscript)
                if best == nil || score > best!.score {
                    best = (phrase, score)
                }
            }
        }

        if let best, best.score >= 0.5 {
            return MatchCandidate(
                intendedText: best.phrase.meaning,
                matchedPhraseId: best.phrase.id,
                confidence: best.score,
                isKnown: true,
                note: "オフライン照合"
            )
        }

        // 一致なし: 聞こえた音をそのまま、低確信度で返す
        return MatchCandidate(
            intendedText: query,
            matchedPhraseId: nil,
            confidence: 0.1,
            isKnown: false,
            note: "オフラインでは一致するフレーズが見つかりませんでした"
        )
    }

    /// 0.0〜1.0 の類似度（1 - 正規化編集距離）。
    private func similarity(_ a: String, _ b: String) -> Double {
        if a.isEmpty && b.isEmpty { return 1 }
        let distance = levenshtein(Array(a), Array(b))
        let maxLen = max(a.count, b.count)
        guard maxLen > 0 else { return 0 }
        return 1.0 - Double(distance) / Double(maxLen)
    }

    private func levenshtein(_ a: [Character], _ b: [Character]) -> Int {
        if a.isEmpty { return b.count }
        if b.isEmpty { return a.count }

        var previous = Array(0...b.count)
        var current = [Int](repeating: 0, count: b.count + 1)

        for i in 1...a.count {
            current[0] = i
            for j in 1...b.count {
                let cost = a[i - 1] == b[j - 1] ? 0 : 1
                current[j] = min(
                    previous[j] + 1,        // 削除
                    current[j - 1] + 1,     // 挿入
                    previous[j - 1] + cost  // 置換
                )
            }
            swap(&previous, &current)
        }
        return previous[b.count]
    }
}
