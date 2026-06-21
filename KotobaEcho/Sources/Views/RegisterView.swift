import SwiftUI

/// 「とうろく」モード（保護者向け）。子の声を録音し、意味を付けて辞書に保存する。
struct RegisterView: View {
    @ObservedObject private var store: PhraseStore
    @StateObject private var viewModel: RegisterViewModel

    init(store: PhraseStore) {
        self.store = store
        _viewModel = StateObject(wrappedValue: RegisterViewModel(store: store))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("1. こどもの こえを ろくおん") {
                    Button {
                        Task { await viewModel.toggleRecording() }
                    } label: {
                        Label(viewModel.isRecording ? "ろくおんを とめる" : "ろくおん",
                              systemImage: viewModel.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                            .foregroundStyle(viewModel.isRecording ? .red : .accentColor)
                    }

                    switch viewModel.phase {
                    case .transcribing:
                        HStack { ProgressView(); Text("よみとり中…") }
                    case .ready:
                        Label("ろくおんできました", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        if !viewModel.roughTranscript.isEmpty {
                            Text("きこえた音: \(viewModel.roughTranscript)")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    case .error(let message):
                        Text(message).foregroundStyle(.red).font(.footnote)
                    default:
                        EmptyView()
                    }
                }

                Section("2. ほんとうの ことば") {
                    TextField("れい: お茶ちょうだい", text: $viewModel.meaning)
                        .textInputAutocapitalization(.never)
                    Button {
                        viewModel.playback()
                    } label: {
                        Label("はつおんを きく", systemImage: "speaker.wave.2")
                    }
                    .disabled(viewModel.meaning.trimmingCharacters(in: .whitespaces).isEmpty)
                }

                Section {
                    Button {
                        viewModel.save()
                    } label: {
                        Label("じしょに とうろく", systemImage: "plus.circle.fill")
                    }
                    .disabled(!viewModel.canSave)
                } footer: {
                    Text("おなじ ことばを なんども とうろくするほど、にんしきが よくなります。")
                }
            }
            .navigationTitle("ことばの とうろく")
        }
    }
}
