# ことばエコー (KotobaEcho) 設計書

## 1. 概要

| 項目 | 内容 |
|------|------|
| アプリ名 | ことばエコー (KotobaEcho) |
| 目的 | 構音障害などで発音が不明瞭な子どもの発話を、**音声の波形**・親子の会話文脈・その子専用の辞書から「一番言いたかった言葉」に推定し、正しい発音で復唱する |
| 対象 | 構音障害・発音の不明瞭さがある子どもと、その保護者 |
| プラットフォーム | iOS / iPadOS（iPhone・iPad両対応） |
| アーキテクチャ | MVVM + SwiftUI |
| 音声認識 | クラウド音声モデルへ**波形を送信**（差し替え可能）。フォールバックに端末内 SFSpeechRecognizer |
| 波形照合 | 波形由来の音響埋め込みをコサイン類似で、その子の登録サンプルと照合 |
| 文脈推論 | Anthropic Messages API / `claude-opus-4-8`（テキストのみ） |
| 音声出力 | AVFoundation（AVSpeechSynthesizer） |
| データ | 端末内 JSON（Application Support）。録音・埋め込み・辞書は端末内に保持 |

### なぜ波形が必須か

汎用の音声認識（SFSpeechRecognizer 等）は**定型発話**向けに訓練されており、構音障害の発話はそもそも正しく書き起こせない。テキスト化した時点で、その子の発話を区別する肝心の**音響情報が失われる**。したがって、テキストだけに頼る設計は成立しない。

本アプリは**波形そのものを主信号**として扱う:

1. 子どもが話す → 録音した**波形をクラウドの音声モデルへ送信**し、N-best候補と**音響埋め込み（声紋的な特徴ベクトル）**を得る
2. その埋め込みを、**その子の登録サンプルの埋め込みとコサイン類似で照合**（＝波形照合）。「その子の声 vs その子の過去の声」を直接比べるので構音の癖に強い（Voiceitt / Project Relate と同じ発想）
3. 音響照合の上位候補＋音声N-best＋会話文脈を **Claude（テキスト）** に渡し、最も自然な「言いたかった言葉」を確定
4. 正しい発音で**復唱**＋文字表示
5. 外れたら保護者が訂正 → その波形・埋め込みが辞書に追加され、認識が育つ

> Claude は音声入力に非対応なので、Claude は「波形処理の結果＋文脈」を受け取る**文脈推論の層**に徹する。波形の処理は別の音声モデルが担う。

---

## 2. アーキテクチャ

```
┌──────────────────────────────────────────────┐
│                    Views                      │
│  RootView / ListenView / RegisterView /       │
│  PhraseListView / SettingsView                │
├───────────────┬──────────────────────────────┤
│  ViewModels   │           Store               │
│  ListenVM     │       PhraseStore             │
│  RegisterVM   │  (辞書・埋め込み・会話履歴・永続化) │
├───────────────┴──────────────────────────────┤
│                  Services                      │
│  AudioRecorder（録音）                          │
│  AudioRecognizing                              │
│    ├ CloudSpeechRecognizer（波形→候補+埋め込み） │
│    └ OnDeviceSpeechRecognizer（端末内・候補のみ） │
│  AcousticMatcher（埋め込みのコサイン照合）         │
│  ClaudeInterpreter / LocalInterpreter（文脈推論）│
│  EchoSpeaker（正しい発音で復唱）                  │
├───────────────────────────────────────────────┤
│                   Models                       │
│  Phrase / PhraseRecording(embedding) /         │
│  ConversationTurn / MatchCandidate / AppConfig │
└───────────────────────────────────────────────┘
```

### 処理フロー（復唱モード）

```
[子] 録音 ─▶ AudioRecorder ─▶ 波形(m4a)
                                  │  base64で送信
                                  ▼
                    CloudSpeechRecognizer（クラウド音声モデル）
                                  │
              ┌───────────────────┴───────────────────┐
              ▼                                       ▼
   N-best候補 [("お茶ちょうらい",0.5)...]      音響埋め込み [floats]
              │                                       │
              │              PhraseStore.phrases ──┐  ▼
              │                                    ▼  ▼
              │                         AcousticMatcher.rank
              │                                    │
              │                     音響照合 [(phraseId,"お茶ちょうだい",0.82)...]
              ▼                                    ▼
       ┌──────────────── ClaudeInterpreter（claude-opus-4-8）────────────────┐
       │  入力: N-best候補 + 音響照合 + 登録辞書 + 直近の会話文脈            │
       └──────────────────────────────┬───────────────────────────────────┘
                                       ▼
                  MatchCandidate { intendedText:"お茶ちょうだい",
                                   matchedPhraseId, confidence, isKnown }
                                       │
                ┌──────────────────────┴──────────────────────┐
                ▼                                             ▼
       EchoSpeaker.speak(...)                     画面表示＋訂正ボタン
                                                            │（外れたら）
                                                            ▼
                              PhraseStore に 波形＋埋め込み を追加（辞書が育つ）
```

---

## 3. データモデル

### 3.1 Phrase（登録フレーズ）
| プロパティ | 型 | 説明 |
|-----------|-----|------|
| `id` | UUID | 識別子 |
| `meaning` | String | 正しい言葉（例「お茶ちょうだい」） |
| `recordings` | [PhraseRecording] | この意味に紐づく音声サンプル群 |
| `timesMatched` | Int | このフレーズが推定された回数 |
| `createdAt` / `updatedAt` | Date | 作成・更新日時 |

### 3.2 PhraseRecording（音声サンプル）
| プロパティ | 型 | 説明 |
|-----------|-----|------|
| `id` | UUID | 識別子 |
| `audioFileName` | String | 端末内の音声ファイル名 |
| `roughTranscript` | String | 音声モデルの最良候補（補助ヒント） |
| `audioEmbedding` | [Float]? | **波形由来の音響埋め込み（照合の主信号）** |
| `createdAt` | Date | 録音日時 |

### 3.3 ConversationTurn / 3.4 MatchCandidate / 3.5 AppConfig
- `ConversationTurn`: 会話の一手（`speaker` / `text` / `createdAt`）
- `MatchCandidate`: 推定結果（`intendedText` / `matchedPhraseId?` / `confidence` / `isKnown` / `note?`）
- `AppConfig`: `cloudEnabled` / `speechBaseURL`（波形の送信先）/ `apiBaseURL`・`model`（Claude）/ `childName`

> 音声モデルキーと Anthropic キーは Keychain に保存。

---

## 4. 画面設計

| 画面 | 役割 |
|------|------|
| ListenView（きく＝子モード） | 大きなマイクボタン → 録音 → 波形認識＋照合＋文脈推論 → 正しい発音で復唱。外れたら「ちがうよ」で訂正 |
| RegisterView（とうろく＝親モード） | 子の声を録音 → 波形(埋め込み)＋意味を辞書に登録 |
| PhraseListView（じしょ） | 登録フレーズ一覧・サンプル数・削除 |
| SettingsView（せってい） | クラウド同意・音声モデル/Claudeの設定・全データ削除 |

---

## 5. クラウド音声モデル契約（CloudSpeechRecognizer）

Claude は音声非対応のため、波形は別エンドポイントへ送る。差し替え可能（汎用ASR・独自の個人特化モデル・自前プロキシ等）。

```
POST {speechBaseURL}/recognize
req : { "audio_base64": "<m4aのbase64>", "format": "m4a", "locale": "ja-JP" }
res : { "candidates": [ {"text":"...", "confidence":0.0-1.0}, ... ],
        "embedding": [Float]   // 波形由来の音響埋め込み（任意）
      }
```

`embedding` を返せば AcousticMatcher による波形照合が効く。返せなくても candidates のみで動作。

---

## 6. プライバシー & セキュリティ

- **重要な変更**: クラウドをオンにすると、より高精度な認識のため**音声の波形がクラウドの音声モデルへ送信される**。子どもの声は最重要の個人情報であり、送信先・同意・保存方針の確認が不可欠。
- クラウドは明示的なオプトイン（`cloudEnabled`）。オフ時は端末内認識のみで、**波形は端末外に出ない**（ただし汎用認識のため精度は限定的）。
- Claude へ送るのはテキスト（候補・音響照合スコア・文脈）のみ。波形は Claude には渡さない。
- 録音・埋め込み・辞書・会話履歴は端末内に保持し、保護者がいつでも全削除できる。
- **APIキーをアプリに同梱しない。** 本番は音声モデル・Claude とも自前バックエンドプロキシ経由にし、キーはサーバ側で保管する（`speechBaseURL` / `apiBaseURL` を差し替え）。
- `Info.plist`: `NSMicrophoneUsageDescription`, `NSSpeechRecognitionUsageDescription`

---

## 7. 今後の拡張

- 端末内で波形特徴量を抽出して照合し、クラウド送信を減らす／止める（プライバシー強化）
- よく使うフレーズのワンタップ復唱（AAC的ボード）
- 推定の正誤ログから「苦手な音」を可視化し、言語訓練（ST）と連携
- iCloud同期（保護者間共有、E2E前提）
