import SwiftUI

/// 「せってい」モード。クラウド同意・音声モデル/Claudeの設定・全データ削除。
struct SettingsView: View {
    @ObservedObject private var store: PhraseStore
    @State private var apiKeyField: String = ""
    @State private var speechKeyField: String = ""
    @State private var showDeleteConfirm = false

    init(store: PhraseStore) {
        self.store = store
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("クラウドを つかう", isOn: cloudBinding)
                } footer: {
                    Text("オンにすると、より高精度な認識のために**音声の波形をクラウドの音声モデルへ送信**します。子どもの声は最重要の個人情報です。送信先・同意・保存方針を必ず確認してください。オフのときは端末内の認識・照合だけで動き、波形は端末外に出ません。")
                }

                if store.config.cloudEnabled {
                    Section("音声モデル（波形の送信先）") {
                        TextField("エンドポイントURL", text: speechBaseURLBinding)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        SecureField("音声モデルのAPIキー", text: $speechKeyField)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        Button("音声キーを ほぞん") { store.speechAPIKey = speechKeyField }
                            .disabled(speechKeyField.isEmpty)
                    } footer: {
                        Text("Claudeは音声非対応のため、波形は別の音声認識エンドポイントへ送ります（汎用ASR・独自の個人特化モデル・自前プロキシ等）。空欄なら端末内認識のみになります。")
                    }

                    Section("文脈推論（Claude）") {
                        SecureField("Anthropic APIキー", text: $apiKeyField)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        Button("キーを ほぞん") { store.apiKey = apiKeyField }
                            .disabled(apiKeyField.isEmpty)
                        TextField("エンドポイントURL", text: apiBaseURLBinding)
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
                    Text("登録フレーズ・録音・会話履歴をすべて消します。")
                }
            }
            .navigationTitle("せってい")
            .onAppear {
                apiKeyField = store.apiKey
                speechKeyField = store.speechAPIKey
            }
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
        Binding(get: { store.config.cloudEnabled }, set: { store.config.cloudEnabled = $0 })
    }
    private var speechBaseURLBinding: Binding<String> {
        Binding(get: { store.config.speechBaseURL }, set: { store.config.speechBaseURL = $0 })
    }
    private var apiBaseURLBinding: Binding<String> {
        Binding(get: { store.config.apiBaseURL }, set: { store.config.apiBaseURL = $0 })
    }
    private var modelBinding: Binding<String> {
        Binding(get: { store.config.model }, set: { store.config.model = $0 })
    }
    private var childNameBinding: Binding<String> {
        Binding(get: { store.config.childName }, set: { store.config.childName = $0 })
    }
}
