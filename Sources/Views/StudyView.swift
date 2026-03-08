import SwiftUI

struct StudyView: View {
    @EnvironmentObject private var store: ProgressStore
    @State private var index = 0
    @State private var cardScale: CGFloat = 1.0
    @State private var cardOffset: CGFloat = 0

    private var currentKana: String {
        KanaCatalog.hiragana[index]
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 1.0, green: 0.55, blue: 0.25),
                    Color(red: 1.0, green: 0.25, blue: 0.6)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // 進捗ドット
                ProgressDots(current: index, total: KanaCatalog.hiragana.count)
                    .padding(.top, 16)

                // 文字カード（タップで読み上げ）
                Button {
                    KanaSpeaker.shared.speak(currentKana)
                    animatePulse()
                } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 36)
                            .fill(.white)
                            .shadow(color: .black.opacity(0.14), radius: 24, x: 0, y: 12)

                        VStack(spacing: 12) {
                            Text(currentKana)
                                .font(.system(size: 200, weight: .bold, design: .rounded))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 1.0, green: 0.35, blue: 0.25),
                                            Color(red: 0.75, green: 0.15, blue: 0.85)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )

                            Label("タップして きく", systemImage: "speaker.wave.2.fill")
                                .font(.title3.bold())
                                .foregroundStyle(Color(red: 0.6, green: 0.3, blue: 0.8).opacity(0.8))
                        }
                    }
                }
                .accessibilityLabel("文字カード。タップすると\(currentKana)を読み上げます")
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .scaleEffect(cardScale)
                .offset(x: cardOffset)

                // 番号表示
                Text("\(index + 1) / \(KanaCatalog.hiragana.count)")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                    .padding(.bottom, 12)

                // ナビゲーション（画面下半分を左右に分割した大きなゾーン）
                HStack(spacing: 12) {
                    // まえ ゾーン（左半分）
                    Button {
                        navigate(forward: false)
                    } label: {
                        VStack(spacing: 10) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 44, weight: .heavy))
                            Text("まえ")
                                .font(.system(size: 26, weight: .heavy, design: .rounded))
                        }
                        .foregroundStyle(index > 0 ? .white : .white.opacity(0.25))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 28)
                                .fill(.white.opacity(index > 0 ? 0.22 : 0.08))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 28)
                                        .stroke(.white.opacity(0.35), lineWidth: 2)
                                )
                        )
                    }
                    .disabled(index == 0)
                    .accessibilityLabel("まえの文字")

                    // つぎ ゾーン（右半分）
                    Button {
                        navigate(forward: true)
                    } label: {
                        VStack(spacing: 10) {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 44, weight: .heavy))
                            Text("つぎ")
                                .font(.system(size: 26, weight: .heavy, design: .rounded))
                        }
                        .foregroundStyle(index < KanaCatalog.hiragana.count - 1 ? .white : .white.opacity(0.25))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 28)
                                .fill(.white.opacity(index < KanaCatalog.hiragana.count - 1 ? 0.22 : 0.08))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 28)
                                        .stroke(.white.opacity(0.35), lineWidth: 2)
                                )
                        )
                    }
                    .disabled(index == KanaCatalog.hiragana.count - 1)
                    .accessibilityLabel("つぎの文字")
                }
                .frame(height: 140)
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
        }
        .navigationTitle("がくしゅう")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onAppear {
            store.recordStudy(kana: currentKana)
        }
    }

    private func navigate(forward: Bool) {
        let dir: CGFloat = forward ? -1 : 1
        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
            cardOffset = dir * 60
            cardScale = 0.88
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            if forward { index += 1 } else { index -= 1 }
            cardOffset = dir * -60
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                cardOffset = 0
                cardScale = 1.0
            }
            store.recordStudy(kana: currentKana)
            KanaSpeaker.shared.speak(currentKana)
        }
    }

    private func animatePulse() {
        withAnimation(.spring(response: 0.25)) { cardScale = 1.06 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.spring(response: 0.25)) { cardScale = 1.0 }
        }
    }
}

private struct ProgressDots: View {
    let current: Int
    let total: Int

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(0..<total, id: \.self) { i in
                    Capsule()
                        .fill(i == current ? .white : .white.opacity(0.32))
                        .frame(width: i == current ? 22 : 8, height: 8)
                        .animation(.spring(response: 0.3), value: current)
                }
            }
            .padding(.horizontal)
        }
    }
}

#Preview {
    NavigationStack {
        StudyView()
            .environmentObject(ProgressStore())
    }
}
