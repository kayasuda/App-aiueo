import SwiftUI

struct QuizResultView: View {
    let correctCount: Int
    let questionCount: Int
    let weakKana: [String]
    let onRetry: () -> Void
    let onHome: () -> Void

    @State private var appeared = false
    @State private var hanamaruScale: CGFloat = 0.3
    @State private var hanamaruRotation: Double = -30
    @State private var showYouTubeReward = false

    private var starCount: Int {
        let ratio = Double(correctCount) / Double(max(questionCount, 1))
        switch ratio {
        case 1.0:        return 3
        case 0.7..<1.0:  return 2
        case 0.4..<0.7:  return 1
        default:         return 0
        }
    }

    private var isPerfect: Bool { correctCount == questionCount }

    private var grade: (emoji: String, message: String, color: Color) {
        switch starCount {
        case 3: return ("🌟", "かんぺき！\nすばらしい！", Color(red: 0.95, green: 0.55, blue: 0.0))
        case 2: return ("😄", "すごい！\nよくできたね！",  Color(red: 0.2, green: 0.75, blue: 0.45))
        case 1: return ("😊", "よくがんばった！",          Color(red: 0.25, green: 0.58, blue: 1.0))
        default: return ("💪", "もういちど\nちょうせんしよう！", Color(red: 0.7, green: 0.4, blue: 1.0))
        }
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.15, green: 0.72, blue: 0.62),
                    Color(red: 0.08, green: 0.48, blue: 0.92)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // 花丸 + スコア
                ZStack {
                    // 花丸
                    HanamaruView(color: grade.color, isPerfect: isPerfect)
                        .frame(width: 220, height: 220)
                        .scaleEffect(hanamaruScale)
                        .rotationEffect(.degrees(hanamaruRotation))

                    // スコア数字
                    VStack(spacing: 2) {
                        Text("\(correctCount)")
                            .font(.system(size: 72, weight: .heavy, design: .rounded))
                            .foregroundStyle(grade.color)
                        Text("/ \(questionCount)")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(grade.color.opacity(0.75))
                    }
                }
                .padding(.bottom, 20)

                // メッセージ
                Text(grade.message)
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .shadow(color: .black.opacity(0.15), radius: 2)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 20)
                    .padding(.bottom, 16)

                // 星
                HStack(spacing: 12) {
                    ForEach(0..<3, id: \.self) { i in
                        Image(systemName: i < starCount ? "star.fill" : "star")
                            .font(.system(size: 44))
                            .foregroundStyle(i < starCount ? .yellow : .white.opacity(0.3))
                            .scaleEffect(appeared && i < starCount ? 1.0 : 0.5)
                            .animation(
                                .spring(response: 0.5, dampingFraction: 0.55)
                                    .delay(0.3 + Double(i) * 0.12),
                                value: appeared
                            )
                    }
                }
                .padding(.bottom, 20)

                // にがて文字
                if !weakKana.isEmpty {
                    VStack(spacing: 10) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.up.heart.fill")
                                .foregroundStyle(.yellow)
                            Text("れんしゅうしよう！")
                                .font(.title3.bold())
                                .foregroundStyle(.white.opacity(0.9))
                        }
                        HStack(spacing: 10) {
                            ForEach(weakKana, id: \.self) { kana in
                                Text(kana)
                                    .font(.system(size: 30, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                                    .frame(width: 56, height: 56)
                                    .background(.white.opacity(0.2))
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14)
                                            .stroke(.white.opacity(0.35), lineWidth: 1.5)
                                    )
                            }
                        }
                    }
                    .padding(.bottom, 20)
                }

                Spacer()

                // ご褒美YouTubeボタン（全問正解のみ）
                if isPerfect {
                    Button {
                        showYouTubeReward = true
                    } label: {
                        HStack(spacing: 14) {
                            Text("🎬")
                                .font(.system(size: 36))
                            VStack(alignment: .leading, spacing: 2) {
                                Text("ごほうび どうが！")
                                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                                    .foregroundStyle(.white)
                                Text("5ふんかん みられるよ")
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.8))
                            }
                            Spacer()
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 36))
                                .foregroundStyle(.white)
                        }
                        .padding(.horizontal, 24)
                        .frame(maxWidth: .infinity)
                        .frame(height: 100)
                        .background(
                            LinearGradient(
                                colors: [Color(red: 1.0, green: 0.2, blue: 0.2), Color(red: 0.9, green: 0.1, blue: 0.4)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 28))
                        .shadow(color: Color(red: 1.0, green: 0.2, blue: 0.2).opacity(0.45), radius: 16, x: 0, y: 8)
                    }
                    .accessibilityLabel("ご褒美のYouTube動画を5分間見る")
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 40)
                }

                // 大きなボタン2つ
                VStack(spacing: 14) {
                    // もういちど（メインアクション）
                    Button(action: onRetry) {
                        HStack(spacing: 14) {
                            Text("🔄")
                                .font(.system(size: 36))
                            Text("もういちど！")
                                .font(.system(size: 30, weight: .heavy, design: .rounded))
                                .foregroundStyle(grade.color)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 100)
                        .background(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 28))
                        .shadow(color: grade.color.opacity(0.35), radius: 16, x: 0, y: 8)
                    }
                    .accessibilityLabel("もう一度クイズをする")

                    // ホームへ
                    Button(action: onHome) {
                        HStack(spacing: 14) {
                            Text("🏠")
                                .font(.system(size: 36))
                            Text("ホームへ かえる")
                                .font(.system(size: 26, weight: .heavy, design: .rounded))
                                .foregroundStyle(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 100)
                        .background(.white.opacity(0.22))
                        .clipShape(RoundedRectangle(cornerRadius: 28))
                        .overlay(
                            RoundedRectangle(cornerRadius: 28)
                                .stroke(.white.opacity(0.45), lineWidth: 2)
                        )
                    }
                    .accessibilityLabel("ホームへ帰る")
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 40)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.55).delay(0.1)) {
                hanamaruScale = 1.0
                hanamaruRotation = 0
            }
            withAnimation(.easeOut(duration: 0.5).delay(0.4)) {
                appeared = true
            }
        }
        .fullScreenCover(isPresented: $showYouTubeReward) {
            YouTubeRewardView(onFinished: { showYouTubeReward = false })
        }
    }
}

// 花丸を描画するView
private struct HanamaruView: View {
    let color: Color
    let isPerfect: Bool

    var body: some View {
        ZStack {
            // 白い背景円
            Circle()
                .fill(.white)
                .frame(width: 200, height: 200)
                .shadow(color: color.opacity(0.3), radius: 16, x: 0, y: 8)

            // 花びら（外側の小さな円）
            ForEach(0..<12, id: \.self) { i in
                Circle()
                    .fill(color.opacity(isPerfect ? 1.0 : 0.6))
                    .frame(width: isPerfect ? 20 : 14, height: isPerfect ? 20 : 14)
                    .offset(y: -108)
                    .rotationEffect(.degrees(Double(i) * 30))
            }

            // メインの丸（花丸の輪）
            Circle()
                .stroke(color, lineWidth: isPerfect ? 14 : 10)
                .frame(width: 168, height: 168)

            // 内側の二重線（満点のとき）
            if isPerfect {
                Circle()
                    .stroke(color.opacity(0.4), lineWidth: 4)
                    .frame(width: 148, height: 148)
            }
        }
    }
}

#Preview {
    QuizResultView(
        correctCount: 5,
        questionCount: 5,
        weakKana: [],
        onRetry: {},
        onHome: {}
    )
}
