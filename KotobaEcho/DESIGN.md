# ことばエコー (KotobaEcho) 設計書

## 1. 概要

| 項目 | 内容 |
|------|------|
| アプリ名 | ことばエコー (KotobaEcho) |
| 目的 | 構音障害などで発音が不明瞭な子どもの発話を、親子の会話データを使って「一番言いたかった言葉」に推定し、正しい発音で復唱する |
| 対象 | 構音障害・発音の不明瞭さがある子どもと、その保護者 |
| プラットフォーム | iOS / iPadOS（iPhone・iPad両対応） |
| アーキテクチャ | MVVM + SwiftUI |
| 通信 | クラウドAI併用（Anthropic Messages API / `claude-opus-4-8`） |
| 音声入力 | AVAudioRecorder + Speech フレームワーク（SFSpeechRecognizer） |
| 音声出力 | AVFoundation（AVSpeechSynthesizer） |
| データ | 端末内 JSON（Application Support）。子どもの音声・発話データは端末内に保持 |

### 着想

保護者は「前後の文脈」からわが子の発音を少しずつ聞き取れるようになる。本アプリはこの**文脈推論のプロセスをAIで再現**する。

1. 子どもが話す → 端末で録音し、音声認識で「ラフな読み（不正確な音）」を得る
2. その**ラフな読み**＋**直近の会話の文脈**＋**その子専用に登録したフレーズ辞書**をクラウドのLLMに渡す
3. LLMが「一番言いたかったであろう言葉」を推定
4. 正しい発音で**復唱**＋文字表示
5. 推定が外れたら保護者が訂正 → その音声サンプルが辞書に追加され、認識が育っていく

これは Google Project Relate / Voiceitt と同じ「個人特化型の発話支援」のアプローチ。汎用音声認識で構音障害を完全に解くのではなく、**その子専用の辞書を少しずつ育てる**ことが核。

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
│  RegisterVM   │   (フレーズ辞書・会話履歴・永続化) │
├───────────────┴──────────────────────────────┤
│                  Services                      │
│  AudioRecorder（録音）                          │
│  SpeechRecognizer（ラフな読みの取得）             │
│  ClaudeInterpreter（文脈推論：クラウドLLM）        │
│  EchoSpeaker（正しい発音で復唱）                  │
├───────────────────────────────────────────────┤
│                   Models                       │
│  Phrase / PhraseRecording / ConversationTurn / │
│  MatchCandidate / AppConfig                    │
└───────────────────────────────────────────────┘
```

### 処理フロー（復唱モード）

```
[子] 録音 ─▶ AudioRecorder ─▶ 音声ファイル
                                  │
                                  ▼
                         SpeechRecognizer ─▶ ラフな読み "おちゃちょーらい"
                                  │
   PhraseStore.knownPhrases ──┐   │   ┌── PhraseStore.recentTurns（文脈）
                              ▼   ▼   ▼
                       ClaudeInterpreter（claude-opus-4-8）
                                  │
                                  ▼
                MatchCandidate { intendedText:"お茶ちょうだい",
                                 matchedPhraseId, confidence, isKnown }
                                  │
                ┌─────────────────┴─────────────────┐
                ▼                                   ▼
       EchoSpeaker.speak("お茶ちょうだい")     画面に文字表示＋訂正ボタン
                                                    │
                                       （外れたら）保護者が訂正
                                                    │
                                                    ▼
                                    PhraseStore に音声サンプルを追加（辞書が育つ）
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
| `roughTranscript` | String | 音声認識で得たラフな読み |
| `createdAt` | Date | 録音日時 |

### 3.3 ConversationTurn（会話の一手）
| プロパティ | 型 | 説明 |
|-----------|-----|------|
| `id` | UUID | 識別子 |
| `speaker` | Speaker | `.child` / `.parent` |
| `text` | String | 発話内容（子は推定後の確定テキスト） |
| `createdAt` | Date | 時刻 |

### 3.4 MatchCandidate（推定結果）
| プロパティ | 型 | 説明 |
|-----------|-----|------|
| `intendedText` | String | 推定した「言いたかった言葉」 |
| `matchedPhraseId` | UUID? | 既存フレーズに一致した場合のID |
| `confidence` | Double | 0.0〜1.0 の確信度 |
| `isKnown` | Bool | 登録辞書に基づく推定か |
| `note` | String? | 補足（推定根拠など） |

### 3.5 AppConfig（設定）
| プロパティ | 型 | 既定 | 説明 |
|-----------|-----|------|------|
| `cloudEnabled` | Bool | false | クラウドLLMの利用同意 |
| `apiBaseURL` | String | `https://api.anthropic.com` | APIエンドポイント（プロキシ差し替え可） |
| `model` | String | `claude-opus-4-8` | 使用モデル |
| `childName` | String | "" | 文脈推論のヒント（任意） |

> APIキーはプロトタイプでは設定画面から入力し Keychain に保存。
> **本番ではアプリにキーを同梱しない**こと（→ §6）。

---

## 4. 画面設計

| 画面 | 役割 |
|------|------|
| RootView | タブ：きく / とうろく / じしょ / せってい |
| ListenView（きく＝子モード） | 大きなマイクボタン → 録音 → 推定テキスト表示 → 正しい発音で復唱。外れたら「ちがうよ」で訂正 |
| RegisterView（とうろく＝親モード） | 子の声を録音 → 意味（正しい言葉）を入力して辞書に保存 |
| PhraseListView（じしょ） | 登録フレーズ一覧・音声サンプル数・削除 |
| SettingsView（せってい） | クラウド利用同意・APIキー・モデル・子の名前・**全データ削除** |

---

## 5. クラウド推論（ClaudeInterpreter）

`POST {apiBaseURL}/v1/messages` に生HTTPで送信。

- モデル: `claude-opus-4-8`
- ヘッダ: `x-api-key`, `anthropic-version: 2023-06-01`, `content-type: application/json`
- `output_config.format`（structured outputs）で結果JSONを保証
- 入力: システムプロンプト（役割＝親のように文脈から推測する支援者）＋
  「ラフな読み」「直近の会話履歴」「その子の登録フレーズ一覧」
- 出力スキーマ:
  ```json
  { "intended_text": "string",
    "matched_phrase_id": "string|null",
    "confidence": 0.0,
    "is_known": true,
    "note": "string|null" }
  ```

`ClaudeInterpreting` プロトコルで抽象化し、テスト・モック・プロキシ差し替えを容易にする。

---

## 6. プライバシー & セキュリティ

- 子どもの音声・発話は**最重要の個人情報**。音声ファイルと辞書は端末内のみに保持し、保護者がいつでも全削除できる。
- クラウド送信は**「ラフな読み（テキスト）」と文脈テキストのみ**。音声波形そのものは送らない設計（音声認識は端末で実施）。
- クラウド利用は明示的なオプトイン（`cloudEnabled`）。同意前はオフライン（辞書の単純照合のみ）で動作。
- **APIキーをアプリに同梱しない。** 本番では自前のバックエンドプロキシ経由にし（`apiBaseURL` を差し替え）、キーはサーバ側に保管する。プロトタイプの直叩き＋Keychain保存はあくまで開発用。
- `Info.plist` に必要な利用目的:
  - `NSMicrophoneUsageDescription`
  - `NSSpeechRecognitionUsageDescription`

---

## 7. 今後の拡張

- 端末内の音声特徴量（MFCC等）による近傍照合で、クラウド前に候補を絞る（精度・コスト・プライバシー向上）
- よく使うフレーズのワンタップ復唱（AAC的ボード）
- 推定の正誤ログから「苦手な音」を可視化し、言語訓練（ST）と連携
- iCloud同期（保護者間でのデバイス共有、E2E前提）
