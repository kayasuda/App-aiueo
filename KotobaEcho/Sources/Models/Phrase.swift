import Foundation

/// 1つの音声サンプル。ある意味（Phrase）に紐づく、子どもの実際の発話の記録。
struct PhraseRecording: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    /// 端末内に保存した音声ファイル名（PhraseStore が管理するディレクトリ内）
    var audioFileName: String
    /// 音声認識で得た「ラフな読み」（不正確な音のテキスト化）。補助的なヒント。
    var roughTranscript: String
    /// 波形から得た音響埋め込み（声紋的な特徴ベクトル）。
    /// その子の発話どうしを直接照合するための主信号。取得できない場合は nil。
    var audioEmbedding: [Float]?
    var createdAt: Date = Date()
}

/// その子専用の辞書エントリ。1つの「正しい言葉(meaning)」に複数の音声サンプルが紐づく。
struct Phrase: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    /// 正しい言葉（例: "お茶ちょうだい"）
    var meaning: String
    /// この意味に紐づく音声サンプル群
    var recordings: [PhraseRecording] = []
    /// このフレーズが推定結果として選ばれた回数
    var timesMatched: Int = 0
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
}
