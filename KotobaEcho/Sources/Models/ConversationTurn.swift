import Foundation

/// 会話の話者。
enum Speaker: String, Codable {
    case child
    case parent

    var label: String {
        switch self {
        case .child: return "こども"
        case .parent: return "おとな"
        }
    }
}

/// 会話の一手。文脈推論のために直近の履歴をAIへ渡す。
struct ConversationTurn: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var speaker: Speaker
    /// 確定したテキスト（子の発話は推定後の言葉）
    var text: String
    var createdAt: Date = Date()
}
