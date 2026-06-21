import Foundation

/// アプリ設定。UserDefaults に保存（APIキーのみ Keychain）。
struct AppConfig: Codable, Equatable {
    /// クラウドLLM利用への明示的同意
    var cloudEnabled: Bool = false
    /// APIエンドポイント。本番では自前プロキシのURLに差し替える。
    var apiBaseURL: String = "https://api.anthropic.com"
    /// 使用モデル
    var model: String = "claude-opus-4-8"
    /// 文脈推論のヒントになる子どもの呼び名（任意）
    var childName: String = ""

    static let `default` = AppConfig()
}
