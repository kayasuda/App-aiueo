import Foundation

/// アプリ設定。UserDefaults に保存（APIキー類のみ Keychain）。
struct AppConfig: Codable, Equatable {
    /// クラウド利用への明示的同意。
    /// オンにすると **音声波形がクラウドの音声モデルへ送信される**点に注意。
    var cloudEnabled: Bool = false

    /// 波形を送る音声認識エンドポイント。空なら端末内認識のみ（波形は端末外に出ない）。
    var speechBaseURL: String = ""

    /// 文脈推論に使う Claude のエンドポイント（本番は自前プロキシに差し替え）。
    var apiBaseURL: String = "https://api.anthropic.com"
    /// Claude のモデル
    var model: String = "claude-opus-4-8"
    /// 文脈推論のヒントになる子どもの呼び名（任意）
    var childName: String = ""

    static let `default` = AppConfig()
}
