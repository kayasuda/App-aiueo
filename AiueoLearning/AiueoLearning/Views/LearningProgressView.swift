import SwiftUI

struct LearningProgressView: View {
    @EnvironmentObject private var store: ProgressStore

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Summary cards
                HStack(spacing: 14) {
                    SummaryCard(
                        icon: "🎯",
                        value: "\(store.dailySessionCount())かい",
                        label: "きょうの\nクイズ",
                        color: Color(red: 0.25, green: 0.58, blue: 1.0)
                    )
                    SummaryCard(
                        icon: "📊",
                        value: "\(store.sessionHistory.count)けん",
                        label: "これまでの\nきろく",
                        color: Color(red: 0.5, green: 0.28, blue: 0.92)
                    )
                }
                .padding(.horizontal, 20)

                // Kana grid
                VStack(alignment: .leading, spacing: 14) {
                    Text("もじごとのしんちょく")
                        .font(.title2.bold())
                        .foregroundStyle(Color(red: 0.18, green: 0.18, blue: 0.28))
                        .padding(.horizontal, 20)

                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 5),
                        spacing: 10
                    ) {
                        ForEach(store.progressList(), id: \.self) { progress in
                            KanaProgressCard(progress: progress)
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
            .padding(.vertical, 20)
        }
        .background(Color(red: 0.96, green: 0.96, blue: 0.98).ignoresSafeArea())
        .navigationTitle("しんちょく")
        .navigationBarTitleDisplayMode(.large)
    }
}

private struct SummaryCard: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Text(icon).font(.system(size: 36))
            Text(value)
                .font(.system(size: 30, weight: .heavy, design: .rounded))
                .foregroundStyle(color)
            Text(label)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .shadow(color: color.opacity(0.14), radius: 12, x: 0, y: 5)
    }
}

private struct KanaProgressCard: View {
    let progress: KanaProgress

    private var accuracy: Double { progress.accuracy }
    private var hasData: Bool {
        progress.quizCorrectCount + progress.quizWrongCount > 0
    }

    private var cardColors: [Color] {
        guard hasData else {
            return [Color(.systemGray4), Color(.systemGray3)]
        }
        if accuracy >= 0.8 {
            return [Color(red: 0.2, green: 0.82, blue: 0.48), Color(red: 0.1, green: 0.65, blue: 0.38)]
        } else if accuracy >= 0.5 {
            return [Color(red: 1.0, green: 0.78, blue: 0.18), Color(red: 1.0, green: 0.52, blue: 0.0)]
        } else {
            return [Color(red: 1.0, green: 0.42, blue: 0.32), Color(red: 0.88, green: 0.2, blue: 0.38)]
        }
    }

    var body: some View {
        VStack(spacing: 3) {
            Text(progress.kana)
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text(hasData ? "\(Int(accuracy * 100))%" : "－")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white.opacity(0.88))
        }
        .frame(maxWidth: .infinity)
        .frame(height: 68)
        .background(
            LinearGradient(
                colors: cardColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: cardColors[0].opacity(0.28), radius: 6, x: 0, y: 3)
    }
}

#Preview {
    NavigationStack {
        LearningProgressView()
            .environmentObject(ProgressStore())
    }
}
