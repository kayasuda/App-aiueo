import SwiftUI

// 外側: リトライのたびにsessionIDを変えてQuizSessionを再生成
struct QuizView: View {
    let mode: QuizMode
    @State private var sessionID = UUID()

    var body: some View {
        QuizSession(mode: mode, onRetry: { sessionID = UUID() })
            .id(sessionID)
    }
}

// 内側: クイズの実際のロジックを持つ
private struct QuizSession: View {
    @EnvironmentObject private var store: ProgressStore
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: QuizViewModel
    @StateObject private var concentrationMonitor = ConcentrationMonitorService()
    @State private var savedResult = false
    @State private var showingAdvice = false
    let onRetry: () -> Void

    init(mode: QuizMode, onRetry: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: QuizViewModel(mode: mode))
        self.onRetry = onRetry
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

            if viewModel.isCompleted {
                QuizResultView(
                    correctCount: viewModel.correctCount,
                    questionCount: viewModel.questionCount,
                    weakKana: store.weakKana().prefix(5).map(\.kana),
                    onRetry: onRetry,
                    onHome: { dismiss() }
                )
                .transition(.opacity)
            } else if let question = viewModel.currentQuestion {
                VStack(spacing: 0) {
                    QuizProgressBar(
                        current: viewModel.currentIndex,
                        total: viewModel.questionCount
                    )
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 8)

                    ZStack {
                        RoundedRectangle(cornerRadius: 30)
                            .fill(.white)
                            .shadow(color: .black.opacity(0.12), radius: 18, x: 0, y: 9)

                        if question.mode == .kanaToAudio {
                            Text(question.kanaPrompt)
                                .font(.system(size: 130, weight: .bold, design: .rounded))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 0.1, green: 0.55, blue: 0.9),
                                            Color(red: 0.45, green: 0.15, blue: 0.9)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .accessibilityLabel("問題: \(question.kanaPrompt)")
                        } else {
                            Button {
                                KanaSpeaker.shared.speak(question.kanaPrompt)
                            } label: {
                                VStack(spacing: 14) {
                                    Image(systemName: "speaker.wave.3.fill")
                                        .font(.system(size: 60))
                                    Text("おとを きく")
                                        .font(.system(size: 26, weight: .heavy, design: .rounded))
                                }
                                .foregroundStyle(Color(red: 0.1, green: 0.55, blue: 0.9))
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                            }
                            .accessibilityLabel("音を再生する")
                        }
                    }
                    .frame(height: 180)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 10)

                    Group {
                        if let isCorrect = viewModel.isCurrentAnswerCorrect {
                            HStack(spacing: 10) {
                                Text(isCorrect ? "⭐️" : "💪")
                                    .font(.system(size: 32))
                                Text(isCorrect ? "せいかい！" : "ざんねん…")
                                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                                    .foregroundStyle(isCorrect ? .white : Color(red: 1.0, green: 0.92, blue: 0.3))
                                Text(isCorrect ? "⭐️" : "💪")
                                    .font(.system(size: 32))
                            }
                            .transition(.scale.combined(with: .opacity))
                        } else {
                            Color.clear.frame(height: 44)
                        }
                    }
                    .frame(height: 52)
                    .animation(.spring(response: 0.4), value: viewModel.isCurrentAnswerCorrect != nil)

                    VStack(spacing: 14) {
                        ForEach(question.choices, id: \.self) { choice in
                            QuizChoiceButton(
                                choice: choice,
                                color: colorFor(choice: choice, question: question),
                                disabled: viewModel.isCurrentAnswerCorrect != nil
                            ) {
                                withAnimation(.spring(response: 0.3)) {
                                    viewModel.select(choice)
                                    if let correct = viewModel.isCurrentAnswerCorrect {
                                        store.recordQuizAnswer(kana: question.correctKana, correct: correct)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)

                    if viewModel.isCurrentAnswerCorrect != nil {
                        Button {
                            withAnimation(.spring(response: 0.4)) {
                                viewModel.advance()
                            }
                        } label: {
                            HStack(spacing: 12) {
                                Text("つぎへ")
                                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                                Image(systemName: "arrow.right.circle.fill")
                                    .font(.system(size: 28))
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 88)
                            .background(.white.opacity(0.22))
                            .clipShape(RoundedRectangle(cornerRadius: 26))
                            .overlay(
                                RoundedRectangle(cornerRadius: 26)
                                    .stroke(.white.opacity(0.45), lineWidth: 2)
                            )
                        }
                        .accessibilityLabel("つぎの問題へ")
                        .padding(.horizontal, 20)
                        .padding(.top, 10)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }

                    Spacer(minLength: 16)
                }
            }
        }
        .overlay {
            if showingAdvice, let advice = concentrationMonitor.lastAdvice {
                ConcentrationAdviceView(message: advice) {
                    showingAdvice = false
                }
            }
        }
        .navigationTitle(viewModel.isCompleted ? "" : "クイズ")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(viewModel.isCompleted)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onChange(of: viewModel.currentIndex) {
            if let q = viewModel.currentQuestion, q.mode == .audioToKana {
                KanaSpeaker.shared.speak(q.kanaPrompt, times: 3)
            }
        }
        .onAppear {
            if let q = viewModel.currentQuestion, q.mode == .audioToKana {
                KanaSpeaker.shared.speak(q.kanaPrompt, times: 3)
            }
            startConcentrationMonitorIfNeeded()
        }
        .onDisappear {
            concentrationMonitor.stopMonitoring()
        }
        .onChange(of: concentrationMonitor.needsCheck) {
            guard concentrationMonitor.needsCheck else { return }
            Task {
                await concentrationMonitor.checkNow(viewModel: viewModel)
            }
        }
        .onChange(of: concentrationMonitor.lastAdvice) {
            if concentrationMonitor.lastAdvice != nil {
                showingAdvice = true
            }
        }
        .onChange(of: viewModel.isCompleted) {
            guard viewModel.isCompleted, !savedResult else { return }
            concentrationMonitor.stopMonitoring()
            let result = QuizSessionResult(
                id: UUID(),
                startedAt: viewModel.startedAt,
                endedAt: Date(),
                questionCount: viewModel.questionCount,
                correctCount: viewModel.correctCount,
                mode: viewModel.mode
            )
            store.saveSession(result)
            savedResult = true
        }
    }

    private func startConcentrationMonitorIfNeeded() {
        guard store.settings.concentrationMonitorEnabled,
              !store.settings.anthropicAPIKey.isEmpty else { return }
        concentrationMonitor.startMonitoring(apiKey: store.settings.anthropicAPIKey)
    }

    private func colorFor(choice: String, question: QuizQuestion) -> Color {
        guard let judged = viewModel.isCurrentAnswerCorrect else {
            return Color(red: 0.25, green: 0.58, blue: 1.0)
        }
        guard let selected = viewModel.selectedChoice else {
            return Color(red: 0.25, green: 0.58, blue: 1.0)
        }
        if choice == question.correctKana { return Color(red: 0.15, green: 0.75, blue: 0.45) }
        if choice == selected && !judged { return Color(red: 0.95, green: 0.32, blue: 0.32) }
        return Color(.systemGray3)
    }
}

private struct QuizChoiceButton: View {
    let choice: String
    let color: Color
    let disabled: Bool
    let action: () -> Void
    @State private var pressed = false

    var body: some View {
        Button(action: action) {
            Text(choice)
                .font(.system(size: 52, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 100)
                .background(color)
                .clipShape(RoundedRectangle(cornerRadius: 26))
                .shadow(color: color.opacity(0.38), radius: 8, x: 0, y: 5)
                .scaleEffect(pressed ? 0.96 : 1.0)
        }
        .disabled(disabled)
        .accessibilityLabel(choice)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in if !disabled { pressed = true } }
                .onEnded { _ in pressed = false }
        )
        .animation(.spring(response: 0.2, dampingFraction: 0.6), value: pressed)
    }
}

private struct QuizProgressBar: View {
    let current: Int
    let total: Int

    var body: some View {
        VStack(spacing: 6) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.28))
                    Capsule()
                        .fill(.white)
                        .frame(width: total > 0 ? geo.size.width * Double(current) / Double(total) : 0)
                        .animation(.spring(response: 0.5), value: current)
                }
            }
            .frame(height: 10)

            Text("もんだい \(min(current + 1, total)) / \(total)")
                .font(.headline.bold())
                .foregroundStyle(.white.opacity(0.9))
        }
    }
}

#Preview {
    NavigationStack {
        QuizView(mode: .audioToKana)
            .environmentObject(ProgressStore())
    }
}
