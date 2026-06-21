import SwiftUI

/// 「せってい」モード。クラウド同意・APIキー・モデル・全データ削除。
struct SettingsView: View {
    @ObservedObject private var store: PhraseStore
    @State private var apiKeyField: String = ""
    @State private var showDeleteConfirm = false

    init(store: PhraseStore) {
        self.store = store
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("クラウドAIを つかう", isOn: cloudBinding)
                } footer: {
                    Text("オンにすると、文脈をふまえた高精度な推定にAIを使います。送信されるのは「聞こえた音のテキスト」と会話文脈のみで、音声そのものは送りません。オフのときは端末内の照合だけで動きます。")
                }

                if store.config.cloudEnabled {
                    Section("APIキー") {
                        SecureField("sk-ant-...", text: $apiKeyField)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        Button("ほぞん") {
                            store.apiKey = apiKeyField
                        }
                        .disabled(apiKeyField.isEmpty)
                    }

                    Section("こうど設定") {
                        TextField("エンドポイントURL", text: baseURLBinding)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        TextField("モデル", text: modelBinding)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    } footer: {
                        Text("本番ではアプリにキーを置かず、自前のプロキシURLを指定してください。キーはサーバー側で管理します。")
                    }
                }

                Section("文脈のヒント") {
                    TextField("こどもの 呼び名（任意）", text: childNameBinding)
                }

                Section {
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Label("すべての データを 削除", systemImage: "trash")
                    }
                } footer: {
                    Text("登録フレーズ・録音・会話履歴をすべて消します。子どもの声は大切な個人情報です。")
                }
            }
            .navigationTitle("せってい")
            .onAppear { apiKeyField = store.apiKey }
            .alert("ぜんぶ消しますか？", isPresented: $showDeleteConfirm) {
                Button("消す", role: .destructive) { store.deleteAllData() }
                Button("やめる", role: .cancel) {}
            } message: {
                Text("この操作は取り消せません。")
            }
        }
    }

    // MARK: - Bindings

    private var cloudBinding: Binding<Bool> {
        Binding(get: { store.config.cloudEnabled },
                set: { store.config.cloudEnabled = $0 })
    }
    private var baseURLBinding: Binding<String> {
        Binding(get: { store.config.apiBaseURL },
                set: { store.config.apiBaseURL = $0 })
    }
    private var modelBinding: Binding<String> {
        Binding(get: { store.config.model },
                set: { store.config.model = $0 })
    }
    private var childNameBinding: Binding<String> {
        Binding(get: { store.config.childName },
                set: { store.config.childName = $0 })
    }
}
