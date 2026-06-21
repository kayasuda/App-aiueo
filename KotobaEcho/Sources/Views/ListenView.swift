import SwiftUI

/// 「きく」モード（子ども向け）。大きなマイクボタンで録音し、推定結果を復唱する。
struct ListenView: View {
    @ObservedObject private var store: PhraseStore
    @StateObject private var viewModel: ListenViewModel
    @State private var showCorrection = false
    @State private var correctionText = ""

    init(store: PhraseStore) {
        self.store = store
        _viewModel = StateObject(wrappedValue: ListenViewModel(store: store))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 28) {
                Spacer()
                statusArea
                Spacer()
                micButton
                Text(viewModel.isRecording ? "はなしてね" : "ボタンをおして はなそう")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding()
            .navigationTitle("ことばエコー")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("リセット") {
                        viewModel.reset()
                        store.clearConversation()
                    }
                    .font(.footnote)
                }
            }
            .sheet(isPresented: $showCorrection) { correctionSheet }
        }
    }

    // MARK: - 状態表示

    @ViewBuilder
    private var statusArea: some View {
        switch viewModel.phase {
        case .idle, .recording:
            EmptyView()
        case .thinking:
            VStack(spacing: 12) {
                ProgressView()
                Text("かんがえているよ…").foregroundStyle(.secondary)
            }
        case .result:
            if let candidate = viewModel.candidate {
                resultCard(candidate)
            }
        case .error(let message):
            VStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.largeTitle)
                    .foregroundStyle(.orange)
                Text(message)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func resultCard(_ candidate: MatchCandidate) -> some View {
        VStack(spacing: 16) {
            Text(candidate.intendedText)
                .font(.system(size: 44, weight: .bold))
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.5)

            confidenceBadge(candidate.confidence)

            HStack(spacing: 16) {
                Button {
                    viewModel.repeatEcho()
                } label: {
                    Label("もういちど", systemImage: "speaker.wave.2.fill")
                }
                .buttonStyle(.borderedProminent)

                Button {
                    correctionText = candidate.intendedText
                    showCorrection = true
                } label: {
                    Label("ちがうよ", systemImage: "pencil")
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20))
        .padding(.horizontal)
    }

    private func confidenceBadge(_ confidence: Double) -> some View {
        let percent = Int(confidence * 100)
        let color: Color = confidence >= 0.75 ? .green : (confidence >= 0.4 ? .orange : .red)
        return Text("じしんど \(percent)%")
            .font(.caption)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(color.opacity(0.15), in: Capsule())
            .foregroundStyle(color)
    }

    // MARK: - マイクボタン

    private var micButton: some View {
        Button {
            Task { await viewModel.toggleRecording() }
        } label: {
            ZStack {
                Circle()
                    .fill(viewModel.isRecording ? Color.red : Color.accentColor)
                    .frame(width: 160, height: 160)
                    .shadow(radius: 8)
                Image(systemName: viewModel.isRecording ? "stop.fill" : "mic.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.white)
            }
        }
        .disabled(viewModel.phase == .thinking)
        .scaleEffect(viewModel.isRecording ? 1.08 : 1.0)
        .animation(.spring(response: 0.3), value: viewModel.isRecording)
    }

    // MARK: - 訂正シート

    private var correctionSheet: some View {
        NavigationStack {
            Form {
                Section("ほんとうは なんて いった？") {
                    TextField("ただしい ことば", text: $correctionText)
                        .textInputAutocapitalization(.never)
                }
                Section {
                    Text("ここで おしえると、つぎから うまく きこえるようになります。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("おしえてね")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("やめる") { showCorrection = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("おぼえる") {
                        viewModel.correct(to: correctionText)
                        showCorrection = false
                    }
                    .disabled(correctionText.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
