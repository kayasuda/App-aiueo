import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var store: ProgressStore
    @State private var titleBounce = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.38, green: 0.55, blue: 1.0),
                    Color(red: 0.65, green: 0.35, blue: 1.0)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // タイトル
                VStack(spacing: 8) {
                    Text("あいうえお")
                        .font(.system(size: 56, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 4)
                        .scaleEffect(titleBounce ? 1.04 : 1.0)
                        .animation(
                            .easeInOut(duration: 2.0).repeatForever(autoreverses: true),
                            value: titleBounce
                        )

                    HStack(spacing: 6) {
                        Image(systemName: "star.fill").foregroundStyle(.yellow)
                        Text("きょうのクイズ: \(store.dailySessionCount())かい")
                            .font(.title3.bold())
                            .foregroundStyle(.white.opacity(0.9))
                        Image(systemName: "star.fill").foregroundStyle(.yellow)
                    }
                }
                .padding(.top, 32)
                .padding(.bottom, 24)

                // メニューボタン（縦並び・フル幅）
                VStack(spacing: 16) {
                    WideMenuButton(
                        title: "がくしゅう する",
                        icon: "📖",
                        color1: Color(red: 1.0, green: 0.45, blue: 0.25),
                        color2: Color(red: 1.0, green: 0.25, blue: 0.5)
                    ) { StudyView() }

                    WideMenuButton(
                        title: "クイズ する",
                        icon: "🎯",
                        color1: Color(red: 0.2, green: 0.78, blue: 0.6),
                        color2: Color(red: 0.1, green: 0.55, blue: 0.85)
                    ) { QuizView(mode: .audioToKana) }

                    WideMenuButton(
                        title: "しんちょく",
                        icon: "⭐️",
                        color1: Color(red: 1.0, green: 0.78, blue: 0.15),
                        color2: Color(red: 1.0, green: 0.48, blue: 0.0)
                    ) { LearningProgressView() }

                    WideMenuButton(
                        title: "せってい",
                        icon: "👨‍👩‍👧",
                        color1: Color(red: 0.68, green: 0.48, blue: 1.0),
                        color2: Color(red: 0.48, green: 0.25, blue: 0.9)
                    ) { ParentSettingsView() }
                }
                .padding(.horizontal, 20)

                Spacer()
            }
        }
        .navigationBarHidden(true)
        .onAppear { titleBounce = true }
    }
}

private struct WideMenuButton<Destination: View>: View {
    let title: String
    let icon: String
    let color1: Color
    let color2: Color
    @ViewBuilder let destination: () -> Destination
    @State private var pressed = false

    var body: some View {
        NavigationLink(destination: destination()) {
            HStack(spacing: 20) {
                Text(icon)
                    .font(.system(size: 48))
                Text(title)
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.15), radius: 2)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(.horizontal, 28)
            .frame(maxWidth: .infinity)
            .frame(height: 100)
            .background(
                LinearGradient(
                    colors: [color1, color2],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 28))
            .shadow(color: color2.opacity(0.4), radius: 12, x: 0, y: 6)
            .scaleEffect(pressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: pressed)
        }
        .accessibilityLabel(title)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in pressed = true }
                .onEnded { _ in pressed = false }
        )
    }
}

#Preview {
    NavigationStack {
        HomeView()
            .environmentObject(ProgressStore())
    }
}
