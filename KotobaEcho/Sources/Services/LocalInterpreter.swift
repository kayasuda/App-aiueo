import Foundation

/// クラウド未使用時のオフライン推定。
/// 音響照合の結果があればそれを最優先し、なければ音声候補のテキストをそのまま採用する。
struct LocalInterpreter: ClaudeInterpreting {

    func interpret(transcriptCandidates: [SpeechCandidate],
                   acousticMatches: [AcousticMatch],
                   knownPhrases: [Phrase],
                   recentTurns: [ConversationTurn],
                   childName: String) async throws -> MatchCandidate {

        // 1. 音響照合（波形の近さ）が十分高ければ採用
        if let top = acousticMatches.first, top.score >= 0.7 {
            return MatchCandidate(
                intendedText: top.meaning,
                matchedPhraseId: top.phraseId,
                confidence: top.score,
                isKnown: true,
                note: "オフライン音響照合"
            )
        }

        // 2. 音声候補の最良テキストを低確信度で返す
        if let best = transcriptCandidates.first, !best.text.isEmpty {
            return MatchCandidate(
                intendedText: best.text,
                matchedPhraseId: nil,
                confidence: min(best.confidence, 0.4),
                isKnown: false,
                note: "オフライン: 音声候補をそのまま採用"
            )
        }

        // 3. 何もなければ空
        return MatchCandidate(
            intendedText: "",
            matchedPhraseId: nil,
            confidence: 0,
            isKnown: false,
            note: "オフラインでは推定できませんでした"
        )
    }
}
