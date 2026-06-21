# ことばエコー (KotobaEcho)

構音障害などで発音が不明瞭な子どもの発話を、**音声の波形**・親子の会話文脈・その子専用に育てる辞書から「一番言いたかった言葉」に推定し、**正しい発音で復唱**する iOS / iPadOS アプリのプロトタイプです。

> 全体設計は [`DESIGN.md`](./DESIGN.md) を参照。

## なぜ波形を使うのか

汎用の音声認識は定型発話向けに訓練されており、構音障害の発話は正しく書き起こせません。テキスト化した時点で、その子の発話を区別する音響情報が失われます。そこで本アプリは**波形そのものを主信号**にします：

1. 録音した**波形をクラウドの音声モデルへ送信** → N-best候補＋**音響埋め込み**を取得
2. 埋め込みを、その子の登録サンプルと**コサイン類似で波形照合**（その子の声 vs その子の過去の声）
3. 音響照合＋音声候補＋会話文脈を **Claude（テキスト）** に渡して最終確定
4. 正しい発音で**復唱**。外れたら親が訂正 → その波形が辞書に追加され精度が育つ

> Claude は音声入力に非対応なので、波形は別の音声認識エンドポイントへ送ります（差し替え可能）。Claude は「波形処理の結果＋文脈」を受け取る文脈推論の層に徹します。

## できること（MVP）

- **きく（子モード）**: マイクボタン → 波形認識＋照合＋文脈推論 → 正しい発音で復唱。「ちがうよ」で訂正学習。
- **とうろく（親モード）**: 子の声を録音し、波形（埋め込み）＋「正しい言葉」を辞書に登録。
- **じしょ**: 登録フレーズの一覧・利用回数・削除。
- **せってい**: クラウド同意、音声モデルのエンドポイント/キー、Claudeのキー/エンドポイント/モデル、全データ削除。

## 構成

```
Sources/
├── KotobaEchoApp.swift
├── Models/        Phrase(+embedding) / ConversationTurn / MatchCandidate / AppConfig
├── Services/      AudioRecorder / AudioRecognizing /
│                  CloudSpeechRecognizer（波形を送信）/ OnDeviceSpeechRecognizer /
│                  AcousticMatcher（波形照合）/ ClaudeInterpreter / LocalInterpreter /
│                  EchoSpeaker / KeychainStore
├── Stores/        PhraseStore
├── ViewModels/    ListenViewModel / RegisterViewModel
└── Views/         RootView / ListenView / RegisterView / PhraseListView / SettingsView
```

## Xcode への取り込み

1. Xcode で iOS App ターゲットを新規作成（SwiftUI / 最小 iOS 17 以上推奨）。
2. `Sources/` 以下をターゲットに追加。`KotobaEchoApp` を `@main` に。
3. `Info.plist` に利用目的を追加：

   ```xml
   <key>NSMicrophoneUsageDescription</key>
   <string>こどもの声を録音して、ことばの推定に使います。</string>
   <key>NSSpeechRecognitionUsageDescription</key>
   <string>録音した声を文字にして、ことばの推定に使います。</string>
   ```

4. 「せってい」でクラウドをオンにし、音声モデルのエンドポイント／キー、Claudeのキー（またはプロキシURL）を設定。

## 音声モデルのエンドポイント契約

Claude は音声非対応のため、波形は `speechBaseURL` で指定する別エンドポイントへ送ります（汎用ASR・独自の個人特化モデル・自前プロキシ等を実装）。

```
POST {speechBaseURL}/recognize
req : { "audio_base64": "<m4aのbase64>", "format": "m4a", "locale": "ja-JP" }
res : { "candidates": [ {"text":"...","confidence":0.0-1.0}, ... ],
        "embedding": [Float]   // 波形由来の音響埋め込み（任意）
      }
```

`embedding` を返すと波形照合（AcousticMatcher）が有効になります。空欄なら端末内認識のみで動作します。

## プライバシー

- **クラウドをオンにすると音声の波形がクラウドへ送信されます。** 子どもの声は最重要の個人情報です。送信先・同意・保存方針を必ず確認してください。
- オフ時は端末内認識のみで波形は端末外に出ません（精度は限定的）。
- Claude へ送るのはテキスト（候補・音響スコア・文脈）のみ。録音・埋め込み・辞書は端末内保持で、いつでも全削除できます。
- **APIキーをアプリに同梱しない**こと。本番は音声モデル・Claudeとも自前プロキシ経由にし、キーはサーバー側で管理します。

## 制約・今後

- 実機ビルドが必要（マイク・認識はシミュレータで制限あり）。本リポジトリはソース雛形（`.xcodeproj` は含めず、既存 `Sources/` ブループリント方式に準拠）。
- 今後: 端末内での波形特徴量抽出による照合（クラウド送信の削減）／ワンタップ復唱／苦手な音の可視化／iCloud同期。詳細は `DESIGN.md` §7。
