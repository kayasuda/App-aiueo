import SwiftUI

/// クイズ中に集中度アドバイスを表示するオーバーレイ
struct ConcentrationAdviceView: View {
    let message: String
    let onDismiss: () -> Void

    @State private var isVisible = false

    var body: some View {
        VStack {
            Spacer()

            if isVisible {
                HStack(spacing: 12) {
                    Text("🐻")
                        .font(.system(size: 38))

                    Text(message)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.leading)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 18)
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.95, green: 0.55, blue: 0.2),
                                    Color(red: 0.9, green: 0.35, blue: 0.5)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .shadow(color: .black.opacity(0.2), radius: 12, x: 0, y: 6)
                )
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .onTapGesture { dismissWithAnimation() }
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                isVisible = true
            }
            // 6秒後に自動的に消す
            DispatchQueue.main.asyncAfter(deadline: .now() + 6) {
                dismissWithAnimation()
            }
        }
        .allowsHitTesting(isVisible)
    }

    private func dismissWithAnimation() {
        withAnimation(.easeInOut(duration: 0.3)) {
            isVisible = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            onDismiss()
        }
    }
}

#Preview {
    ZStack {
        Color.blue.ignoresSafeArea()
        ConcentrationAdviceView(message: "すごい！がんばってるね！") {}
    }
}
