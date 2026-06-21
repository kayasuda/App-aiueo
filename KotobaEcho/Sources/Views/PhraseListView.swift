import SwiftUI

/// 「じしょ」モード。登録フレーズ一覧と削除。
struct PhraseListView: View {
    @ObservedObject private var store: PhraseStore

    init(store: PhraseStore) {
        self.store = store
    }

    var body: some View {
        NavigationStack {
            Group {
                if store.phrases.isEmpty {
                    ContentUnavailableView(
                        "まだ ことばが ありません",
                        systemImage: "book",
                        description: Text("「とうろく」で こどもの ことばを おぼえさせましょう。")
                    )
                } else {
                    List {
                        ForEach(store.phrases.sorted(by: { $0.timesMatched > $1.timesMatched })) { phrase in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(phrase.meaning).font(.headline)
                                    Spacer()
                                    Button {
                                        EchoSpeaker.shared.speak(phrase.meaning)
                                    } label: {
                                        Image(systemName: "speaker.wave.2")
                                    }
                                    .buttonStyle(.borderless)
                                }
                                Text("おんせいサンプル \(phrase.recordings.count)けん ・ つかった \(phrase.timesMatched)かい")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                let roughs = phrase.recordings
                                    .map { $0.roughTranscript }
                                    .filter { !$0.isEmpty }
                                if !roughs.isEmpty {
                                    Text("きこえ方: \(roughs.joined(separator: " / "))")
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                        .onDelete(perform: deleteRows)
                    }
                }
            }
            .navigationTitle("ことばの じしょ")
        }
    }

    private func deleteRows(at offsets: IndexSet) {
        let sorted = store.phrases.sorted(by: { $0.timesMatched > $1.timesMatched })
        for index in offsets {
            store.deletePhrase(sorted[index].id)
        }
    }
}
