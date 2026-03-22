import Foundation

/// 回答状況のスナップショット（前回チェック時点との比較用）
struct ProgressSnapshot {
    let answeredCount: Int
    let correctCount: Int
    let averageResponseTime: TimeInterval
    let lastResponseTime: TimeInterval?
    let totalElapsed: TimeInterval
    let recentLogs: [AnswerLog]  // 前回チェック以降の回答
}

/// 回答進捗を30秒ごとに Claude API で分析し、声かけを生成するサービス
@MainActor
final class ConcentrationMonitorService: ObservableObject {
    @Published private(set) var lastAdvice: String?
    @Published private(set) var isAnalyzing = false

    private var timer: Timer?
    private var apiKey: String = ""
    private var lastCheckedLogCount: Int = 0

    /// 監視を開始する (30秒間隔)
    func startMonitoring(apiKey: String) {
        self.apiKey = apiKey
        lastCheckedLogCount = 0
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.requestCheck()
            }
        }
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
        lastAdvice = nil
        lastCheckedLogCount = 0
    }

    /// QuizViewModel から呼ばれるチェック要求用のコールバック
    private var pendingCheck: (() -> Void)?

    /// 外部から viewModel を渡して分析を実行
    func checkNow(viewModel: QuizViewModel) async {
        await checkConcentration(viewModel: viewModel)
    }

    /// タイマーから呼ばれる — 次回の body 評価時に viewModel 経由でチェック
    private func requestCheck() {
        // objectWillChange を発火して QuizView に通知
        objectWillChange.send()
        needsCheck = true
    }

    /// QuizView 側で監視し、true になったら checkNow を呼ぶ
    @Published var needsCheck = false

    private func checkConcentration(viewModel: QuizViewModel) async {
        needsCheck = false
        guard !isAnalyzing else { return }

        let logs = viewModel.answerLogs
        let recentLogs = Array(logs.dropFirst(lastCheckedLogCount))

        // 前回から回答がなく、かつ問題が表示中 = 長時間無回答
        let totalElapsed = Date().timeIntervalSince(viewModel.startedAt)

        let snapshot = ProgressSnapshot(
            answeredCount: logs.count,
            correctCount: viewModel.correctCount,
            averageResponseTime: logs.isEmpty ? 0 : logs.map(\.responseTime).reduce(0, +) / Double(logs.count),
            lastResponseTime: logs.last?.responseTime,
            totalElapsed: totalElapsed,
            recentLogs: recentLogs
        )

        lastCheckedLogCount = logs.count

        isAnalyzing = true
        defer { isAnalyzing = false }

        let advice = await analyzeWithClaude(snapshot: snapshot, viewModel: viewModel)
        if let advice {
            lastAdvice = advice
        }
    }

    private func buildPrompt(snapshot: ProgressSnapshot, viewModel: QuizViewModel) -> String {
        var lines: [String] = []
        lines.append("あなたは4〜6歳の子ども向けひらがな学習アプリの見守りアシスタントです。")
        lines.append("以下はクイズの回答状況データです。この子の集中度を判定して、やさしく声かけしてください。")
        lines.append("")
        lines.append("【クイズ進捗】")
        lines.append("- 全問数: \(viewModel.questionCount)")
        lines.append("- 回答済み: \(snapshot.answeredCount)問")
        lines.append("- 正解数: \(snapshot.correctCount)問")
        lines.append("- 経過時間: \(Int(snapshot.totalElapsed))秒")
        lines.append("- 平均回答時間: \(String(format: "%.1f", snapshot.averageResponseTime))秒")

        if let last = snapshot.lastResponseTime {
            lines.append("- 最後の回答にかかった時間: \(String(format: "%.1f", last))秒")
        }

        if !snapshot.recentLogs.isEmpty {
            lines.append("")
            lines.append("【直近の回答（前回チェック以降）】")
            for log in snapshot.recentLogs {
                let mark = log.isCorrect ? "○" : "×"
                lines.append("- 「\(log.kana)」\(mark)（\(String(format: "%.1f", log.responseTime))秒）")
            }
        } else {
            lines.append("")
            lines.append("【注意】前回チェックから30秒間、1問も回答がありません。")
        }

        lines.append("")
        lines.append("""
        上のデータから子どもの状態を推測し、ひらがなだけで短い声かけを1文だけ返してください。
        漢字・カタカナは使わないでください。

        判定のヒント:
        - 回答が速くて正解率が高い → よく集中している → ほめる
        - 回答が遅くなってきた → 集中が切れてきた → はげます
        - 30秒間回答なし → ぼーっとしているか離席 → やさしく呼びかける
        - 不正解が続いている → 疲れや混乱 → やすむことをすすめる
        - 正解率が高くテンポも良い → のっている → もっとはげます

        声かけの1文だけを返してください。説明は不要です。
        """)

        return lines.joined(separator: "\n")
    }

    private func analyzeWithClaude(snapshot: ProgressSnapshot, viewModel: QuizViewModel) async -> String? {
        guard !apiKey.isEmpty else { return nil }

        let url = URL(string: "https://api.anthropic.com/v1/messages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let prompt = buildPrompt(snapshot: snapshot, viewModel: viewModel)

        let body: [String: Any] = [
            "model": "claude-sonnet-4-20250514",
            "max_tokens": 150,
            "messages": [
                [
                    "role": "user",
                    "content": prompt
                ]
            ]
        ]

        guard let httpBody = try? JSONSerialization.data(withJSONObject: body) else { return nil }
        request.httpBody = httpBody

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else { return nil }

            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let content = json["content"] as? [[String: Any]],
               let firstBlock = content.first,
               let text = firstBlock["text"] as? String {
                return text.trimmingCharacters(in: .whitespacesAndNewlines)
                    .trimmingCharacters(in: CharacterSet(charactersIn: "「」"))
            }
            return nil
        } catch {
            return nil
        }
    }
}
