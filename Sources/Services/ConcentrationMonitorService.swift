import Foundation
import UIKit

/// 画像を Claude API に送信して集中度を判定するサービス
@MainActor
final class ConcentrationMonitorService: ObservableObject {
    @Published private(set) var lastAdvice: String?
    @Published private(set) var isAnalyzing = false

    private let cameraService = CameraService()
    private var timer: Timer?
    private var apiKey: String = ""

    /// 監視を開始する (30秒間隔)
    func startMonitoring(apiKey: String) {
        self.apiKey = apiKey
        cameraService.start()
        // 最初の撮影は5秒後 (カメラ準備時間)
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.checkConcentration()
            }
        }
        // 初回は5秒後に実行
        Task {
            try? await Task.sleep(for: .seconds(5))
            await checkConcentration()
        }
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
        cameraService.stop()
        lastAdvice = nil
    }

    private func checkConcentration() async {
        guard !isAnalyzing else { return }
        isAnalyzing = true
        defer { isAnalyzing = false }

        guard let image = await cameraService.capturePhoto(),
              let base64 = compressAndEncode(image) else {
            return
        }

        let advice = await analyzeWithClaude(base64Image: base64)
        if let advice {
            lastAdvice = advice
        }
    }

    private func compressAndEncode(_ image: UIImage) -> String? {
        // 解像度を下げてデータ量を削減
        let maxDimension: CGFloat = 512
        let scale = min(maxDimension / image.size.width, maxDimension / image.size.height, 1.0)
        let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)

        UIGraphicsBeginImageContextWithOptions(newSize, true, 1.0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let resized = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        guard let data = resized?.jpegData(compressionQuality: 0.5) else { return nil }
        return data.base64EncodedString()
    }

    private func analyzeWithClaude(base64Image: String) async -> String? {
        guard !apiKey.isEmpty else { return nil }

        let url = URL(string: "https://api.anthropic.com/v1/messages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": "claude-sonnet-4-20250514",
            "max_tokens": 200,
            "messages": [
                [
                    "role": "user",
                    "content": [
                        [
                            "type": "image",
                            "source": [
                                "type": "base64",
                                "media_type": "image/jpeg",
                                "data": base64Image
                            ]
                        ],
                        [
                            "type": "text",
                            "text": """
                            あなたは4〜6歳の子ども向け学習アプリの見守りアシスタントです。
                            この画像はクイズ中の子どもの様子です。

                            子どもの集中度を判定し、やさしく短い声かけを1文だけ返してください。
                            ひらがなだけで書いてください（漢字・カタカナは使わないでください）。

                            例：
                            - 集中している場合: 「すごい！がんばってるね！」
                            - よそ見している場合: 「おっと！がめんを みてみよう！」
                            - 疲れていそうな場合: 「すこし やすんでも いいんだよ」
                            - 姿勢が悪い場合: 「せなかを ぴん！としてみよう」

                            声かけの1文だけを返してください。説明は不要です。
                            """
                        ]
                    ]
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
                // 余計な引用符や空白を除去
                return text.trimmingCharacters(in: .whitespacesAndNewlines)
                    .trimmingCharacters(in: CharacterSet(charactersIn: "「」"))
            }
            return nil
        } catch {
            return nil
        }
    }
}
