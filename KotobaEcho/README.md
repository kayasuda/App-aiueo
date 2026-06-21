# ことばエコー (KotobaEcho)

構音障害などで発音が不明瞭な子どもの発話を、**親子の会話の文脈**と**その子専用に育てる辞書**から「一番言いたかった言葉」に推定し、**正しい発音で復唱**する iOS / iPadOS アプリのプロトタイプです。

> 着想・全体設計は [`DESIGN.md`](./DESIGN.md) を参照。

## できること（MVP）

- **きく（子モード）**: マイクボタンで録音 → 端末で音声認識 → 文脈＋辞書からAIが言葉を推定 → 正しい発音で復唱。外れたら「ちがうよ」で訂正でき、その音声が辞書に追加されて精度が育つ。
- **とうろく（親モード）**: 子の声を録音し「正しい言葉」を付けて辞書に登録。
- **じしょ**: 登録フレーズの一覧・利用回数・削除。
- **せってい**: クラウドAI利用の同意、APIキー、エンドポイント／モデル、全データ削除。

## アーキテクチャ

MVVM + SwiftUI。`PhraseStore` を単一データソースに、`AudioRecorder`（録音）・`SpeechRecognizer`（ラフな読み）・`ClaudeInterpreter`（文脈推論）・`EchoSpeaker`（復唱）を組み合わせます。クラウドのLLMには Anthropic Messages API（`claude-opus-4-8`）を生HTTPで利用。詳細は `DESIGN.md`。

```
Sources/
├── KotobaEchoApp.swift
├── Models/        Phrase / ConversationTurn / MatchCandidate / AppConfig
├── Services/      AudioRecorder / SpeechRecognizer / EchoSpeaker /
│                  ClaudeInterpreter / LocalInterpreter / KeychainStore
├── Stores/        PhraseStore
├── ViewModels/    ListenViewModel / RegisterViewModel
└── Views/         RootView / ListenView / RegisterView /
                   PhraseListView / SettingsView
```

## Xcode への取り込み

このディレクトリは（既存の `Sources/` ブループリントと同様に）ソース一式の雛形です。実機で動かすには：

1. Xcode で iOS App ターゲットを新規作成（SwiftUI / 最小 iOS 17 以上推奨）。
2. `Sources/` 以下のファイルをターゲットに追加。`KotobaEchoApp` を `@main` のエントリにする。
3. `Info.plist` に利用目的の説明を追加：

   ```xml
   <key>NSMicrophoneUsageDescription</key>
   <string>こどもの声を録音して、ことばの推定に使います。</string>
   <key>NSSpeechRecognitionUsageDescription</key>
   <string>録音した声を文字にして、ことばの推定に使います。</string>
   ```

4. 「せってい」でクラウドAIをオンにし、APIキー（またはプロキシURL）を設定。

## クラウドAIの使い方

- **同意制**: 「せってい」でオンにしたときだけクラウドを使います。オフのときは端末内の照合（`LocalInterpreter`）のみで動作します。
- **送るのはテキストだけ**: 音声認識は端末で行い、クラウドへ送るのは「聞こえた音のテキスト」「直近の会話文脈」「登録フレーズ」のみ。音声波形は送りません。
- **APIキーをアプリに同梱しない**: プロトタイプは Keychain 保存＋直叩きですが、**本番は自前のバックエンドプロキシ経由**にしてください（「せってい」のエンドポイントURLをプロキシに変更）。キーはサーバー側で管理します。`ClaudeInterpreter` は `apiBaseURL` を差し替えるだけでプロキシ対応できます。

## プライバシー

子どもの音声・発話は最重要の個人情報です。録音・辞書・会話履歴はすべて端末内に保持し、「せってい」→「すべてのデータを削除」でいつでも全消去できます。

## 制約・今後

- 端末では実機ビルドが必要（音声認識・マイクはシミュレータで制限あり）。
- 今後: 端末内の音声特徴量による近傍照合でクラウド前に候補を絞る／よく使う語のワンタップ復唱／苦手な音の可視化／iCloud同期（E2E前提）。詳細は `DESIGN.md` §7。
