# あいうえお学習アプリ 設計書

## 1. 概要

| 項目 | 内容 |
|------|------|
| アプリ名 | あいうえお学習アプリ (Aiueo Learning) |
| 対象年齢 | 4〜6歳 |
| プラットフォーム | iPadOS (iPad専用) |
| 収益モデル | 買い切り型 (有料アプリ) |
| 対象文字 | ひらがな46文字 |

本アプリは、未就学児がひらがな46文字を楽しく学べるiPad向け学習アプリである。
直感的なタップ操作と音声読み上げにより、文字の形と音を結びつけて学習できる。

---

## 2. 技術スタック

| 要素 | 技術 |
|------|------|
| 言語 | Swift 5+ |
| UIフレームワーク | SwiftUI |
| 音声合成 | AVFoundation (`AVSpeechSynthesizer`) |
| データ永続化 | UserDefaults + JSON |
| アーキテクチャ | MVVM |
| ビルドシステム | Xcode / Swift Package Manager |
| 最小SDK | iOS / iPadOS 26 |

---

## 3. アーキテクチャ

### 3.1 全体構成

```
┌─────────────────────────────────────────────┐
│                   Views                      │
│  (SwiftUI画面 × 6)                           │
│  HomeView / StudyView / QuizView /           │
│  QuizResultView / LearningProgressView /     │
│  ParentSettingsView                          │
├──────────────┬──────────────────────────────┤
│  ViewModel   │         Store                │
│  QuizVM      │    ProgressStore             │
│  (クイズ制御) │  (状態管理・永続化)            │
├──────────────┴──────────────────────────────┤
│              Services                        │
│         KanaSpeaker (音声合成)                │
├─────────────────────────────────────────────┤
│              Models                          │
│  KanaCatalog / KanaProgress / AppSettings /  │
│  QuizMode / QuizSessionResult                │
└─────────────────────────────────────────────┘
```

### 3.2 設計方針

- **MVVM + SwiftUI Environment Objects**: `ProgressStore` を中心とした単一データソース
- **@MainActor**: UI更新をメインスレッドで保証
- **Singleton**: `KanaSpeaker.shared` による音声合成の一元管理
- **ネットワーク不要**: 完全ローカル動作、バックエンドなし

---

## 4. ディレクトリ構成

```
App-aiueo/
├── Sources/                        # メインソースコード
│   ├── AiueoLearningApp.swift     # アプリエントリーポイント (@main)
│   ├── Models/                     # データモデル
│   │   ├── KanaCatalog.swift      # ひらがな46文字の定義
│   │   ├── KanaProgress.swift     # 文字ごとの学習進捗
│   │   ├── AppSettings.swift      # アプリ設定
│   │   ├── QuizMode.swift         # クイズモード列挙型
│   │   └── QuizSessionResult.swift # クイズセッション結果
│   ├── Services/                   # ビジネスロジック
│   │   └── KanaSpeaker.swift      # 音声読み上げサービス
│   ├── Stores/                     # 状態管理
│   │   └── ProgressStore.swift    # 学習進捗の管理・永続化
│   ├── ViewModels/                 # プレゼンテーションロジック
│   │   └── QuizViewModel.swift    # クイズ画面の状態管理
│   └── Views/                      # UI画面
│       ├── ContentView.swift      # ナビゲーションルート
│       ├── HomeView.swift         # ホーム画面
│       ├── StudyView.swift        # 学習画面
│       ├── QuizView.swift         # クイズ画面
│       ├── QuizResultView.swift   # クイズ結果画面
│       ├── LearningProgressView.swift # 学習進捗画面
│       └── ParentSettingsView.swift   # 保護者設定画面
├── AiueoLearning/                  # Xcodeプロジェクト (本番用)
│   ├── AiueoLearning.xcodeproj/
│   └── AiueoLearning/             # ターゲットディレクトリ
│       ├── Assets.xcassets/       # アイコン・カラーアセット
│       └── (Sources/ と同一構成のソースファイル)
├── AiueoApp/                       # レガシーXcodeプロジェクト
├── AppRequirements.md              # MVP要件定義
└── DEPLOY_GUIDE.md                 # App Storeデプロイ手順
```

**コード規模**: Swiftファイル16個、約1,400行

---

## 5. データモデル

### 5.1 KanaCatalog

ひらがな46文字を定義する列挙型。五十音順に格納。

```swift
enum KanaCatalog {
    static let all: [String] = [
        "あ","い","う","え","お",
        "か","き","く","け","こ",
        // ... 全46文字
    ]
}
```

### 5.2 KanaProgress

文字ごとの学習進捗を追跡する。

| プロパティ | 型 | 説明 |
|-----------|-----|------|
| `kana` | String | 対象のひらがな |
| `shownCount` | Int | 学習画面での表示回数 |
| `quizCorrectCount` | Int | クイズ正解数 |
| `quizWrongCount` | Int | クイズ不正解数 |
| `lastStudiedAt` | Date? | 最終学習日時 |
| `accuracy` | Double (計算) | 正答率 (正解 / 全回答) |

### 5.3 AppSettings

| プロパティ | 型 | デフォルト | 説明 |
|-----------|-----|----------|------|
| `bgmEnabled` | Bool | true | BGMの有効/無効 |
| `sfxEnabled` | Bool | true | 効果音の有効/無効 |
| `dailyGoalMinutes` | Int | 10 | 1日の学習目標(分) |
| `purchased` | Bool | true | 購入フラグ |

### 5.4 QuizSessionResult

| プロパティ | 型 | 説明 |
|-----------|-----|------|
| `id` | UUID | セッション識別子 |
| `startedAt` | Date | 開始日時 |
| `endedAt` | Date | 終了日時 |
| `questionCount` | Int | 出題数 |
| `correctCount` | Int | 正解数 |
| `mode` | QuizMode | クイズモード |

### 5.5 QuizMode

| 値 | 説明 |
|-----|------|
| `audioToKana` | 音声を聞いて文字を選ぶ |
| `kanaToAudio` | 文字を見て読みを選ぶ |

---

## 6. 画面設計

### 6.1 画面遷移図

```
                    ┌──────────┐
                    │  ホーム   │
                    │ HomeView │
                    └────┬─────┘
           ┌─────────┬──┴──┬──────────┐
           ▼         ▼     ▼          ▼
      ┌────────┐ ┌──────┐ ┌────────┐ ┌────────┐
      │ 学習   │ │クイズ│ │ 進捗   │ │ 設定   │
      │StudyV. │ │QuizV.│ │Progress│ │ParentS.│
      └────────┘ └──┬───┘ └────────┘ └────────┘
                    ▼
              ┌──────────┐
              │ クイズ結果│
              │ResultView│
              └──────────┘
```

### 6.2 各画面の詳細

#### ホーム画面 (HomeView)
- アニメーション付きグラデーション背景（青→紫）
- バウンスアニメーションの「あいうえお」タイトル
- 今日のクイズ回数表示（星アイコン）
- 4つのメニューボタン（学習・クイズ・進捗・設定）
- ボタン押下時のスプリングアニメーション

#### 学習画面 (StudyView)
- 大きな文字カード（タップで音声読み上げ）
- グラデーションテキスト（オレンジ→紫）
- 46文字中の現在位置を示すプログレスドット
- 前へ/次へナビゲーションボタン
- カード切替時のスプリングスライドアニメーション

#### クイズ画面 (QuizView)
- 画面上部のプログレスバー
- 問題表示（文字またはスピーカーアイコン）
- 3択の回答ボタン
- 正解/不正解のフィードバック（色変化・メッセージ）
- 音声の自動再生（問題開始時に3回読み上げ）

#### クイズ結果画面 (QuizResultView)
- はなまるスタンプアニメーション
- 星評価（0〜3つ星）
- 日本語の励ましメッセージ
- 苦手な文字の表示（最大5文字）
- 「もういちど」/「ホームにもどる」ボタン

#### 学習進捗画面 (LearningProgressView)
- サマリーカード（今日のクイズ数・累計セッション数）
- 5列グリッドで全文字表示
- 文字ごとの正答率をカラーコードで表示
  - 灰色: 未テスト
  - 緑: 80%以上
  - オレンジ: 50〜80%
  - 赤: 50%未満

#### 保護者設定画面 (ParentSettingsView)
- BGM・効果音のON/OFFトグル
- 1日の学習目標（ステッパー: 5〜30分）
- 購入状態の表示

---

## 7. 主要コンポーネント

### 7.1 ProgressStore (状態管理)

アプリ全体の状態管理と永続化を担う中核コンポーネント。

**永続化キー**:
| キー | 内容 |
|------|------|
| `app_settings_v1` | アプリ設定 |
| `kana_progress_v1` | 文字ごとの進捗 |
| `quiz_session_v1` | クイズセッション履歴 |

**主要メソッド**:
| メソッド | 説明 |
|---------|------|
| `updateSettings()` | 設定の変更・保存 |
| `recordStudy()` | 学習記録の追加 |
| `recordQuizAnswer()` | クイズ回答の記録 |
| `saveSession()` | セッション保存(最大30件) |
| `progressList()` | 全文字の進捗一覧(五十音順) |
| `dailySessionCount()` | 今日のクイズ回数 |
| `weakKana()` | 苦手な文字の抽出(正答率60%未満) |

### 7.2 QuizViewModel (クイズ制御)

クイズの問題生成・回答処理・進行管理を行う。

- 問題はランダム生成（正解1 + 不正解2の3択）
- `SystemRandomNumberGenerator` による問題順のシャッフル
- 即時フィードバック（回答直後に正誤表示）

### 7.3 KanaSpeaker (音声合成)

- Singletonパターン (`KanaSpeaker.shared`)
- 日本語音声 (ja-JP)
- 読み上げ速度: 0.38、ピッチ: 1.15
- オーディオセッション: `.playback` + `.duckOthers`

---

## 8. データフロー

```
ユーザー操作
    │
    ▼
  View (SwiftUI)
    │
    ├─── 学習操作 ──→ ProgressStore.recordStudy()
    │                        │
    ├─── クイズ回答 ──→ QuizViewModel.select()
    │                        │
    │                  ProgressStore.recordQuizAnswer()
    │                        │
    ├─── 音声再生 ──→ KanaSpeaker.speak()
    │
    ▼
  ProgressStore (@Published)
    │
    ├── UserDefaults (JSON) ──→ 永続化
    │
    └── View更新 ──→ SwiftUI再描画
```

---

## 9. UI/UXの設計指針

### 子ども向けの配慮
- **大きなタップ領域**: ボタンの高さ100pt以上
- **明確なフィードバック**: 色変化・アニメーション・音声
- **シンプルなナビゲーション**: フラットな画面遷移
- **ビビッドなグラデーション**: 視覚的に魅力的な配色
- **外部リンク・広告なし**: 安全な学習環境

### アクセシビリティ
- 全インタラクティブ要素にアクセシビリティラベルを設定
- 高コントラストなカラーデザイン

### アニメーション
- スプリングアニメーションによる軽快な操作感
- カード切替・ボタン押下時の即時フィードバック
- 結果画面でのスケール/フェードインアニメーション

---

## 10. 制約事項・今後の拡張

### 現在の制約
- ひらがな46文字のみ（濁音・半濁音・拗音は含まない）
- 完全オフライン動作（データ同期なし）
- セッション履歴は最大30件まで保持
- テキスト音声合成を使用（録音済み音声ではない）
- iPad専用（iPhoneには未対応）

### 将来の拡張候補
- カタカナの追加
- 濁音・半濁音・拗音の追加
- 手書き入力による文字認識
- 単語学習モード
- 学習リマインダー通知
- iCloud同期によるデバイス間データ共有
