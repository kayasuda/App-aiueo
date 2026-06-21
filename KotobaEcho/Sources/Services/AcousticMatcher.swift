import Foundation

/// 音響照合の結果（その子の登録フレーズと、今の発話の波形がどれだけ近いか）。
struct AcousticMatch: Hashable {
    var phraseId: UUID
    var meaning: String
    /// 0.0〜1.0 のコサイン類似度（最も近い登録サンプルとの値）
    var score: Double
}

/// 波形由来の音響埋め込みどうしをコサイン類似で照合する。
/// = 「その子の声 vs その子の過去の声」を直接比べる、本アプリの中核ロジック。
enum AcousticMatcher {

    /// 今の発話の埋め込みを、各フレーズの登録サンプルと照合し、近い順に返す。
    static func rank(query: [Float], phrases: [Phrase], limit: Int = 3) -> [AcousticMatch] {
        guard !query.isEmpty else { return [] }

        var matches: [AcousticMatch] = []
        for phrase in phrases {
            // フレーズ内の各サンプルとの最大類似度を採用
            var best = -1.0
            for recording in phrase.recordings {
                guard let embedding = recording.audioEmbedding, !embedding.isEmpty else { continue }
                let sim = cosine(query, embedding)
                if sim > best { best = sim }
            }
            if best >= 0 {
                matches.append(AcousticMatch(phraseId: phrase.id, meaning: phrase.meaning, score: best))
            }
        }

        return Array(matches.sorted { $0.score > $1.score }.prefix(limit))
    }

    /// コサイン類似度（次元が異なる場合は 0）。
    static func cosine(_ a: [Float], _ b: [Float]) -> Double {
        guard a.count == b.count, !a.isEmpty else { return 0 }
        var dot: Float = 0, na: Float = 0, nb: Float = 0
        for i in 0..<a.count {
            dot += a[i] * b[i]
            na += a[i] * a[i]
            nb += b[i] * b[i]
        }
        let denom = (na.squareRoot() * nb.squareRoot())
        guard denom > 0 else { return 0 }
        return Double(dot / denom)
    }
}
