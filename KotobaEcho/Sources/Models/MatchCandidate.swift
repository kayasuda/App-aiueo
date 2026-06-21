import Foundation

/// クラウド推論（ClaudeInterpreter）が返す「言いたかった言葉」の推定結果。
struct MatchCandidate: Codable, Hashable {
    /// 推定した、子どもが言いたかったであろう言葉
    var intendedText: String
    /// 登録辞書のフレーズに一致した場合のID
    var matchedPhraseId: UUID?
    /// 0.0〜1.0 の確信度
    var confidence: Double
    /// 登録辞書に基づく推定なら true（未知の新しい言い回しなら false）
    var isKnown: Bool
    /// 推定の補足・根拠（任意）
    var note: String?
}
