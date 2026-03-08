import SwiftUI
import WebKit

struct YouTubeRewardView: View {
    let onFinished: () -> Void

    @State private var remainingSeconds: Int = 5 * 60
    @State private var timerActive = true
    @State private var showConfirmClose = false

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var timeText: String {
        let m = remainingSeconds / 60
        let s = remainingSeconds % 60
        return String(format: "%d:%02d", m, s)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // タイマーバー
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: "clock.fill")
                            .foregroundStyle(.yellow)
                        Text("のこり \(timeText)")
                            .font(.system(size: 22, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                            .monospacedDigit()
                    }

                    Spacer()

                    Button {
                        showConfirmClose = true
                    } label: {
                        Text("おわる")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(.white.opacity(0.2))
                            .clipShape(Capsule())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color(white: 0.12))

                // プログレスバー
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Rectangle().fill(Color.white.opacity(0.15))
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [.green, .yellow],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geo.size.width * Double(remainingSeconds) / Double(5 * 60))
                            .animation(.linear(duration: 1), value: remainingSeconds)
                    }
                }
                .frame(height: 6)

                // YouTube WebView
                YouTubeWebView()
                    .ignoresSafeArea(edges: .bottom)
            }

            // タイムアップオーバーレイ
            if remainingSeconds <= 0 {
                Color.black.opacity(0.85).ignoresSafeArea()

                VStack(spacing: 20) {
                    Text("⏰")
                        .font(.system(size: 80))
                    Text("じかんだよ！")
                        .font(.system(size: 36, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                    Text("またぜんもんせいかいしたら\nみられるよ！")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.8))
                        .multilineTextAlignment(.center)

                    Button(action: onFinished) {
                        Text("もどる")
                            .font(.system(size: 28, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                            .frame(width: 200, height: 70)
                            .background(
                                LinearGradient(
                                    colors: [Color(red: 0.2, green: 0.78, blue: 0.6), Color(red: 0.1, green: 0.55, blue: 0.85)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 22))
                    }
                }
            }
        }
        .onReceive(timer) { _ in
            guard timerActive, remainingSeconds > 0 else { return }
            remainingSeconds -= 1
            if remainingSeconds <= 0 {
                timerActive = false
            }
        }
        .alert("どうがを おわる？", isPresented: $showConfirmClose) {
            Button("みる", role: .cancel) {}
            Button("おわる", role: .destructive) { onFinished() }
        }
        .navigationBarHidden(true)
    }
}

// YouTube Kids トップページを表示する WKWebView ラッパー
private struct YouTubeWebView: UIViewRepresentable {
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.scrollView.isScrollEnabled = true
        if let url = URL(string: "https://www.youtubekids.com") {
            webView.load(URLRequest(url: url))
        }
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

#Preview {
    YouTubeRewardView(onFinished: {})
}
