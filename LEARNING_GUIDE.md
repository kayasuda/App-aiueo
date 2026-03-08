# あいうえおアプリ コーディング学習ガイド

このガイドでは、「あいうえおラーニング」アプリのコード全体を、初心者にもわかるように順番に解説します。

---

## 目次

1. [全体構成](#1-全体構成)
2. [アプリのエントリーポイント](#2-アプリのエントリーポイント--aiueolearningappswift)
3. [データモデル（Models）](#3-データモデルmodels)
4. [サービス層（Services）](#4-サービス層services)
5. [データ管理（Stores）](#5-データ管理stores)
6. [ビューモデル（ViewModels）](#6-ビューモデルviewmodels)
7. [画面（Views）](#7-画面views)
8. [Swift基本文法まとめ](#8-swift基本文法まとめ)

---

## 1. 全体構成

```
Sources/
├── AiueoLearningApp.swift     ← アプリの起動地点（エントリーポイント）
├── Models/                    ← データの「形」を定義する場所
│   ├── AppSettings.swift      ← アプリの設定（BGM・効果音・目標時間）
│   ├── KanaCatalog.swift      ← ひらがな46文字の一覧
│   ├── KanaProgress.swift     ← 1文字ごとの学習記録
│   ├── QuizMode.swift         ← クイズの出題モード
│   └── QuizSessionResult.swift← クイズ1回分の結果
├── Services/                  ← 外部機能との橋渡し
│   └── KanaSpeaker.swift      ← 音声読み上げ機能
├── Stores/                    ← データの保存・読み込みを管理
│   └── ProgressStore.swift    ← 学習進捗の保存・管理
├── ViewModels/                ← 画面のロジック（頭脳）
│   └── QuizViewModel.swift    ← クイズ画面の出題・採点ロジック
└── Views/                     ← ユーザーが見る画面（見た目）
    ├── ContentView.swift      ← 最初に表示される画面の枠
    ├── HomeView.swift         ← ホーム画面（メニュー）
    ├── StudyView.swift        ← 学習画面（文字カード）
    ├── QuizView.swift         ← クイズ画面
    ├── QuizResultView.swift   ← クイズ結果画面
    ├── LearningProgressView.swift ← 学習進捗画面
    └── ParentSettingsView.swift   ← 保護者向け設定画面
```

### 設計パターン：MVVM

このアプリは **MVVM（Model-View-ViewModel）** というパターンで作られています。

| 層 | 役割 | 例え |
|---|---|---|
| **Model** | データの形を定義 | 「成績表のフォーマット」 |
| **View** | 画面の見た目 | 「黒板に書かれた内容」 |
| **ViewModel** | 画面のロジック | 「先生（問題を出す・採点する）」 |
| **Store** | データの保存 | 「成績表を保管する棚」 |

---

## 2. アプリのエントリーポイント — AiueoLearningApp.swift

```swift
import SwiftUI                           // ① SwiftUIフレームワークを読み込む

@main                                    // ② 「ここからアプリが始まる」という印
struct AiueoLearningApp: App {           // ③ App プロトコルに準拠した構造体
    @StateObject private var store = ProgressStore()  // ④ データ管理オブジェクトを作成

    var body: some Scene {               // ⑤ アプリの画面構成を定義
        WindowGroup {                    // ⑥ ウィンドウ（画面の枠）
            ContentView()                // ⑦ 最初に表示する画面
                .environmentObject(store)// ⑧ 全画面でstoreを共有できるようにする
        }
    }
}
```

### 文法解説

| 番号 | コード | 意味 |
|---|---|---|
| ① | `import SwiftUI` | SwiftUIライブラリを使えるようにする。Pythonの`import`と同じ |
| ② | `@main` | 「このアプリはここから起動する」という目印 |
| ③ | `struct ... : App` | `App`プロトコル（ルール）に従った構造体を定義 |
| ④ | `@StateObject` | SwiftUIが管理するオブジェクト。画面が更新されても消えない |
| ⑤ | `var body: some Scene` | アプリの画面構成を返す計算プロパティ |
| ⑥ | `WindowGroup` | iPadの1つのウィンドウを表す |
| ⑦ | `ContentView()` | ContentViewという画面を作って表示 |
| ⑧ | `.environmentObject(store)` | `store`を子画面すべてで使えるように共有する |

**ポイント**: `@StateObject`で作ったオブジェクトは、`.environmentObject()`で渡すと、どの子画面からでも`@EnvironmentObject`で受け取れます。これは「全員が見える掲示板」のようなものです。

---

## 3. データモデル（Models）

### 3-1. KanaCatalog.swift — ひらがな一覧

```swift
import Foundation                        // 基本的な機能を読み込む

enum KanaCatalog {                       // ① enum（列挙型）をデータの入れ物として使う
    static let hiragana: [String] = [    // ② static = 共有データ、let = 変更不可
        "あ", "い", "う", "え", "お",     // ③ String（文字列）の配列
        "か", "き", "く", "け", "こ",
        // ... 46文字
    ]
}
```

**文法ポイント**:
- `enum`（列挙型）: ここではインスタンスを作らせない「名前空間」として使っている。`KanaCatalog.hiragana`のようにアクセスする
- `static`: クラスや構造体に属するデータ。インスタンスを作らなくても使える
- `let`: 定数（一度決めたら変えられない）。`var`は変数（変えられる）
- `[String]`: 文字列の配列型。`["あ", "い", ...]`のようなリスト

### 3-2. KanaProgress.swift — 1文字の学習記録

```swift
struct KanaProgress: Codable, Hashable { // ① struct = データの箱、Codable = 保存可能
    let kana: String                     // ② そのひらがな文字（変更不可）
    var shownCount: Int                  // ③ 学習画面で見た回数（変更可能）
    var quizCorrectCount: Int            // ④ クイズ正解数
    var quizWrongCount: Int              // ⑤ クイズ不正解数
    var lastStudiedAt: Date?             // ⑥ 最後に学習した日時（?はnilの可能性あり）

    var accuracy: Double {               // ⑦ 計算プロパティ（正答率を計算）
        let total = quizCorrectCount + quizWrongCount
        guard total > 0 else { return 0 }  // ⑧ 0問なら0を返す（0除算防止）
        return Double(quizCorrectCount) / Double(total)  // ⑨ 型変換して割り算
    }
}
```

**文法ポイント**:
- `struct`: 構造体。データをまとめる箱。`class`と違い、値型（コピーされる）
- `Codable`: JSON形式に変換できるようにするプロトコル（保存に必要）
- `Hashable`: 辞書のキーやSetに使えるようにするプロトコル
- `Date?`: `?`はオプショナル型。「値があるかもしれないし、ないかもしれない（nil）」
- `guard ... else { return }`: 条件を満たさなければ早期リターン。「門番」のような役割
- `Double(...)`: 型変換。IntからDoubleに変換して小数点の計算を可能にする

### 3-3. QuizMode.swift — クイズの出題モード

```swift
enum QuizMode: String, Codable, CaseIterable {  // ① 選択肢を定義する列挙型
    case audioToKana                              // ② 音を聞いて文字を選ぶ
    case kanaToAudio                              // ③ 文字を見て音を選ぶ

    var title: String {                           // ④ 計算プロパティ
        switch self {                             // ⑤ switch文で分岐
        case .audioToKana:
            return "おとを きいて もじを えらぼう"
        case .kanaToAudio:
            return "もじを みて おとを えらぼう"
        }
    }
}
```

**文法ポイント**:
- `enum`: 列挙型。決まった選択肢の中から1つを選ぶときに使う
- `case`: enumの各選択肢
- `CaseIterable`: すべてのcaseをリストで取得できるようにする
- `switch self`: 自分自身がどのcaseかで分岐する

### 3-4. QuizSessionResult.swift — クイズ結果

```swift
struct QuizSessionResult: Codable, Identifiable { // ① Identifiable = 一意に識別可能
    let id: UUID                                   // ② UUID = ユニークなID（重複しない）
    let startedAt: Date                            // ③ 開始時刻
    let endedAt: Date                              // ④ 終了時刻
    let questionCount: Int                         // ⑤ 問題数
    let correctCount: Int                          // ⑥ 正解数
    let mode: QuizMode                             // ⑦ クイズモード
}
```

**文法ポイント**:
- `Identifiable`: SwiftUIのリスト表示で各要素を区別するために必要なプロトコル
- `UUID`: 世界で一意のID。`UUID()`で新しいIDを生成できる

### 3-5. AppSettings.swift — アプリ設定

```swift
struct AppSettings: Codable {
    var bgmEnabled: Bool = true          // ① Bool型 + デフォルト値
    var sfxEnabled: Bool = true          // ② 効果音のON/OFF
    var dailyGoalMinutes: Int = 10       // ③ 1日の目標（分）
    var purchased: Bool = true           // ④ 購入済みかどうか
}
```

**文法ポイント**:
- `Bool`: 真偽値（`true`または`false`）
- `= true`: デフォルト値。初期化時に値を指定しなければこの値が使われる

---

## 4. サービス層（Services）

### KanaSpeaker.swift — 音声読み上げ

```swift
import AVFoundation                      // ① 音声・動画関連のフレームワーク

final class KanaSpeaker {                // ② final = 継承禁止のクラス
    static let shared = KanaSpeaker()    // ③ シングルトンパターン（1個だけ存在）
    private let synthesizer = AVSpeechSynthesizer()  // ④ 音声合成エンジン

    private init() {                     // ⑤ private init = 外部からインスタンス作成禁止
        configureAudioSession()
    }

    private func configureAudioSession() {  // ⑥ 音声セッションの設定
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio, options: .duckOthers)
        try? session.setActive(true)
    }

    func speak(_ text: String, times: Int = 1) {  // ⑦ 読み上げメソッド
        synthesizer.stopSpeaking(at: .immediate)    // ⑧ 前の読み上げを止める
        for i in 0..<max(1, times) {                // ⑨ 指定回数繰り返す
            let utterance = AVSpeechUtterance(string: text)  // ⑩ 発話オブジェクト作成
            utterance.voice = AVSpeechSynthesisVoice(language: "ja-JP")  // ⑪ 日本語音声
            utterance.rate = 0.38                    // ⑫ 話す速さ（ゆっくり）
            utterance.pitchMultiplier = 1.15         // ⑬ 声の高さ（子供向けに少し高め）
            utterance.volume = 1.0                   // ⑭ 音量（最大）
            if i < times - 1 {
                utterance.postUtteranceDelay = 0.5   // ⑮ 繰り返し間の間隔（秒）
            }
            synthesizer.speak(utterance)             // ⑯ 読み上げ実行
        }
    }
}
```

**文法ポイント**:
- `final class`: 継承（サブクラス化）を禁止したクラス。パフォーマンスが少し良くなる
- `static let shared`: **シングルトンパターン**。アプリ全体で1つだけのインスタンスを作る設計パターン
- `private init()`: 初期化メソッドを外部から呼べなくする → `KanaSpeaker()`を外部で書けない
- `try?`: エラーが出る可能性がある処理を実行。エラー時はnilを返す（クラッシュしない）
- `0..<max(1, times)`: 半開範囲演算子。0から`max(1, times) - 1`まで
- `_ text: String`: `_`はラベル省略。呼ぶ時に`speak("あ")`と書ける（`speak(text: "あ")`でなく）

---

## 5. データ管理（Stores）

### ProgressStore.swift — 学習進捗の管理

このファイルはアプリの「データベース」のような役割です。

```swift
@MainActor                               // ① メインスレッドで動くことを保証
final class ProgressStore: ObservableObject {  // ② 画面に変化を通知できるクラス
    @Published var settings: AppSettings          // ③ 値が変わると画面が自動更新
    @Published private(set) var kanaProgress: [String: KanaProgress]  // ④ 辞書型
    @Published private(set) var sessionHistory: [QuizSessionResult]   // ⑤ 配列型

    private let defaults: UserDefaults    // ⑥ iOSの簡易データ保存機能
    private let encoder = JSONEncoder()   // ⑦ データ → JSON に変換する道具
    private let decoder = JSONDecoder()   // ⑧ JSON → データ に変換する道具

    private let settingsKey = "app_settings_v1"   // ⑨ 保存時のキー（名前）
    private let progressKey = "kana_progress_v1"
    private let sessionKey = "quiz_session_v1"
```

**文法ポイント**:
- `@MainActor`: UIの更新はメインスレッドで行う必要がある。この属性で保証する
- `ObservableObject`: このクラスの`@Published`プロパティが変わると、画面が自動で再描画される
- `@Published`: この値が変わったことを画面に通知する
- `private(set)`: 外部から読み取りはOK、書き込みはこのクラス内部のみ
- `[String: KanaProgress]`: 辞書型。`["あ": KanaProgressオブジェクト, "い": ...]`のような形

#### 初期化メソッド

```swift
    init(defaults: UserDefaults = .standard) {  // ① デフォルト引数付き初期化
        self.defaults = defaults
        self.settings = AppSettings()
        self.kanaProgress = [:]              // ② 空の辞書
        self.sessionHistory = []             // ③ 空の配列
        load()                               // ④ 保存データを読み込む
        bootstrapMissingKana()               // ⑤ 足りない文字の進捗を追加
    }
```

#### データ記録メソッド

```swift
    func recordStudy(kana: String, at date: Date = Date()) {
        guard var progress = kanaProgress[kana] else { return }  // ① 辞書から取得
        progress.shownCount += 1             // ② カウント+1
        progress.lastStudiedAt = date        // ③ 日時を記録
        kanaProgress[kana] = progress        // ④ 辞書に戻す（structはコピーなので必要）
        saveProgress()                       // ⑤ UserDefaultsに保存
    }

    func recordQuizAnswer(kana: String, correct: Bool, at date: Date = Date()) {
        guard var progress = kanaProgress[kana] else { return }
        if correct {                         // ⑥ if文で分岐
            progress.quizCorrectCount += 1
        } else {
            progress.quizWrongCount += 1
        }
        progress.lastStudiedAt = date
        kanaProgress[kana] = progress
        saveProgress()
    }
```

#### データ保存・読み込み

```swift
    private func load() {
        // UserDefaultsからデータを読み込む
        if let data = defaults.data(forKey: settingsKey),      // ① オプショナルバインディング
           let saved = try? decoder.decode(AppSettings.self, from: data) { // ② JSONデコード
            settings = saved
        }
        // ... 同様にkanaProgressとsessionHistoryも読み込む
    }

    private func saveSettings() {
        if let data = try? encoder.encode(settings) {  // ③ JSONエンコード
            defaults.set(data, forKey: settingsKey)     // ④ UserDefaultsに保存
        }
    }
```

**文法ポイント**:
- `if let ... = ...`: **オプショナルバインディング**。nilでなければ値を取り出す
- `try? decoder.decode(型.self, from: data)`: JSONデータを指定した型に変換。失敗したらnil
- `defaults.set(data, forKey: key)`: キーと値のペアでデータを保存

#### 便利メソッド

```swift
    func weakKana(threshold: Double = 0.6) -> [KanaProgress] {
        progressList()
            .filter { ($0.quizCorrectCount + $0.quizWrongCount) > 0 && $0.accuracy < threshold }
            // ↑ filter: 条件に合うものだけ残す。$0は各要素を指す
            .sorted { $0.accuracy < $1.accuracy }
            // ↑ sorted: 並び替え。$0と$1は比較する2要素
    }
```

**文法ポイント**:
- `.filter { 条件 }`: 配列から条件に合うものだけ取り出す
- `.sorted { 比較 }`: 配列を並び替える
- `$0`, `$1`: クロージャの省略引数名。`$0`は第1引数、`$1`は第2引数

---

## 6. ビューモデル（ViewModels）

### QuizViewModel.swift — クイズのロジック

```swift
struct QuizQuestion {                    // ① クイズ1問分のデータ
    let kanaPrompt: String               // 出題する文字
    let choices: [String]                // 選択肢（3つ）
    let correctKana: String              // 正解の文字
    let mode: QuizMode                   // 出題モード
}

@MainActor
final class QuizViewModel: ObservableObject {
    @Published private(set) var questions: [QuizQuestion] = []  // 問題リスト
    @Published private(set) var currentIndex: Int = 0           // 今何問目か
    @Published private(set) var correctCount: Int = 0           // 正解数
    @Published private(set) var isCompleted: Bool = false        // 全問終了したか
    @Published var selectedChoice: String?        // ユーザーが選んだ選択肢
    @Published var isCurrentAnswerCorrect: Bool?  // 今の回答が正解かどうか
```

#### 問題生成ロジック

```swift
    static func generateQuestions(count: Int, mode: QuizMode) -> [QuizQuestion] {
        var rng = SystemRandomNumberGenerator()         // ① 乱数生成器
        let kana = KanaCatalog.hiragana
        var result: [QuizQuestion] = []

        for _ in 0..<count {                            // ② _ は使わない変数の省略
            let correct = kana.randomElement(using: &rng) ?? "あ"  // ③ ランダムに1つ選ぶ
            let wrongPool = kana.filter { $0 != correct }          // ④ 正解以外を取り出す
                                .shuffled(using: &rng)             // ⑤ シャッフル
            let wrongChoices = Array(wrongPool.prefix(2))          // ⑥ 先頭2つ取得
            let choices = ([correct] + wrongChoices)               // ⑦ 正解+不正解を合体
                            .shuffled(using: &rng)                 // ⑧ 順番をシャッフル
            result.append(QuizQuestion(...))
        }
        return result
    }
```

**文法ポイント**:
- `for _ in 0..<count`: ループ変数を使わない場合`_`で省略
- `?? "あ"`: **nil合体演算子**。左がnilなら右の値を使う
- `&rng`: `inout`パラメータ。関数内で値を変更するために`&`をつける
- `.prefix(2)`: 配列の先頭2要素を取得
- `[correct] + wrongChoices`: 配列の結合

#### 回答・進行ロジック

```swift
    func select(_ choice: String) {
        guard isCurrentAnswerCorrect == nil,           // ① まだ回答してない
              let current = currentQuestion            // ② 現在の問題がある
        else { return }
        selectedChoice = choice
        let correct = (choice == current.correctKana)  // ③ 正解かどうか判定
        isCurrentAnswerCorrect = correct
        if correct { correctCount += 1 }
    }

    func advance() {
        guard isCurrentAnswerCorrect != nil else { return }  // 回答済みでなければ進めない
        selectedChoice = nil                  // ④ リセット
        isCurrentAnswerCorrect = nil

        if currentIndex + 1 >= questionCount {
            isCompleted = true                // ⑤ 全問終了
        } else {
            currentIndex += 1                 // ⑥ 次の問題へ
        }
    }
```

---

## 7. 画面（Views）

### 7-1. ContentView.swift — 最初の画面の枠

```swift
struct ContentView: View {               // ① View プロトコルに準拠
    var body: some View {                // ② 画面の中身を定義する計算プロパティ
        NavigationStack {                // ③ 画面遷移を管理するコンテナ
            HomeView()                   // ④ ホーム画面を表示
        }
    }
}

#Preview {                               // ⑤ Xcodeのプレビュー用マクロ
    ContentView()
        .environmentObject(ProgressStore())
}
```

**文法ポイント**:
- `struct ... : View`: すべての画面は`View`プロトコルに準拠する
- `var body: some View`: 画面の見た目を返すプロパティ。`some View`は「何かしらのView」
- `NavigationStack`: 画面の「戻る」ボタンやページ遷移を管理する
- `#Preview`: Xcodeで画面のプレビューを表示するためのマクロ

### 7-2. HomeView.swift — ホーム画面

```swift
struct HomeView: View {
    @EnvironmentObject private var store: ProgressStore  // ① 共有データを受け取る
    @State private var titleBounce = false               // ② この画面だけの状態

    var body: some View {
        ZStack {                                          // ③ 要素を重ねて配置
            // 背景グラデーション
            LinearGradient(                               // ④ グラデーション（色の段階変化）
                colors: [Color(red: 0.38, green: 0.55, blue: 1.0),
                         Color(red: 0.65, green: 0.35, blue: 1.0)],
                startPoint: .topLeading,                  // 左上から
                endPoint: .bottomTrailing                 // 右下へ
            )
            .ignoresSafeArea()                            // ⑤ 画面端まで広げる

            VStack(spacing: 0) {                          // ⑥ 縦に並べる
                // タイトル
                Text("あいうえお")
                    .font(.system(size: 56, weight: .heavy, design: .rounded))  // ⑦ フォント設定
                    .foregroundStyle(.white)               // ⑧ 文字色
                    .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 4) // ⑨ 影
                    .scaleEffect(titleBounce ? 1.04 : 1.0)  // ⑩ 拡大縮小アニメ
                    .animation(                            // ⑪ アニメーション設定
                        .easeInOut(duration: 2.0).repeatForever(autoreverses: true),
                        value: titleBounce
                    )
```

**文法ポイント**:
- `@EnvironmentObject`: 親から`.environmentObject()`で渡されたオブジェクトを受け取る
- `@State`: この画面だけが持つ状態。値が変わると画面が再描画される
- `ZStack`: Z軸（奥行き方向）に重ねて配置。背景の上にコンテンツを置くのに便利
- `VStack`: 縦（Vertical）に並べる。`HStack`は横（Horizontal）に並べる
- `LinearGradient`: 色のグラデーション背景
- `.ignoresSafeArea()`: ノッチや角丸を無視して画面端まで描画
- `条件 ? 値A : 値B`: **三項演算子**。条件がtrueならA、falseならB

#### メニューボタン（カスタムコンポーネント）

```swift
private struct WideMenuButton<Destination: View>: View {  // ① ジェネリクス
    let title: String
    let icon: String
    let color1: Color
    let color2: Color
    @ViewBuilder let destination: () -> Destination       // ② クロージャで画面を受け取る
    @State private var pressed = false

    var body: some View {
        NavigationLink(destination: destination()) {       // ③ タップで画面遷移
            HStack(spacing: 20) {
                Text(icon).font(.system(size: 48))
                Text(title)
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                Spacer()                                   // ④ 残りのスペースを埋める
                Image(systemName: "chevron.right")         // ⑤ SF Symbolsアイコン
            }
            .frame(maxWidth: .infinity)                    // ⑥ 横幅いっぱいに広げる
            .frame(height: 100)
            .background(LinearGradient(...))
            .clipShape(RoundedRectangle(cornerRadius: 28)) // ⑦ 角丸で切り抜く
        }
    }
}
```

**文法ポイント**:
- `<Destination: View>`: **ジェネリクス**。どんなView型でも受け取れるようにする
- `@ViewBuilder`: 複数のViewを返せるクロージャ
- `NavigationLink`: タップすると別の画面に遷移するボタン
- `Spacer()`: 空白を入れて要素を端に押しやる
- `Image(systemName: ...)`: Appleが提供するSF Symbolsアイコンを使用
- `.frame(maxWidth: .infinity)`: 利用可能な最大幅に広げる
- `.clipShape(...)`: 指定した形に切り抜く

### 7-3. StudyView.swift — 学習画面

```swift
struct StudyView: View {
    @EnvironmentObject private var store: ProgressStore
    @State private var index = 0                    // ① 今何番目の文字か
    @State private var cardScale: CGFloat = 1.0     // ② カードの拡大率
    @State private var cardOffset: CGFloat = 0      // ③ カードの横移動量

    private var currentKana: String {               // ④ 計算プロパティで現在の文字を取得
        KanaCatalog.hiragana[index]
    }
```

#### 文字カード（タップで読み上げ）

```swift
            Button {                                     // ① ボタン（タップで実行）
                KanaSpeaker.shared.speak(currentKana)    // ② 読み上げ
                animatePulse()                           // ③ アニメーション
            } label: {                                   // ④ ボタンの見た目
                ZStack {
                    RoundedRectangle(cornerRadius: 36)
                        .fill(.white)
                    Text(currentKana)
                        .font(.system(size: 200, weight: .bold, design: .rounded))
                        .foregroundStyle(LinearGradient(...))  // ⑤ グラデーション文字色
                }
            }
            .scaleEffect(cardScale)                      // ⑥ 拡大縮小を適用
            .offset(x: cardOffset)                       // ⑦ 横移動を適用
```

#### ナビゲーションアニメーション

```swift
    private func navigate(forward: Bool) {
        let dir: CGFloat = forward ? -1 : 1              // ① 方向を決定
        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {  // ② アニメ付き
            cardOffset = dir * 60                        // ③ カードを横にずらす
            cardScale = 0.88                             // ④ カードを縮小
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { // ⑤ 0.18秒後に実行
            if forward { index += 1 } else { index -= 1 }       // ⑥ インデックスを更新
            cardOffset = dir * -60                               // ⑦ 反対側から
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                cardOffset = 0                                   // ⑧ 元の位置に戻す
                cardScale = 1.0
            }
            store.recordStudy(kana: currentKana)                 // ⑨ 学習記録を保存
            KanaSpeaker.shared.speak(currentKana)                // ⑩ 読み上げ
        }
    }
```

**文法ポイント**:
- `withAnimation { ... }`: ブロック内の状態変更にアニメーションを付ける
- `.spring(response:dampingFraction:)`: バネのような自然なアニメーション
- `DispatchQueue.main.asyncAfter(deadline:)`: 指定時間後にメインスレッドで実行

#### ProgressDots（進捗ドット）

```swift
private struct ProgressDots: View {
    let current: Int
    let total: Int

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {  // ① 横スクロール
            HStack(spacing: 6) {
                ForEach(0..<total, id: \.self) { i in      // ② 繰り返し表示
                    Capsule()                               // ③ カプセル形状
                        .fill(i == current ? .white : .white.opacity(0.32))  // ④ 条件で色変更
                        .frame(width: i == current ? 22 : 8, height: 8)     // ⑤ 条件でサイズ変更
                }
            }
        }
    }
}
```

**文法ポイント**:
- `ForEach(0..<total, id: \.self)`: 範囲をループして要素を繰り返し表示
- `id: \.self`: 各要素を自身の値で識別する
- `.opacity(0.32)`: 透明度（0.0=完全透明、1.0=不透明）

### 7-4. QuizView.swift — クイズ画面

```swift
// 外側: リトライのたびにsessionIDを変えてQuizSessionを再生成
struct QuizView: View {
    let mode: QuizMode
    @State private var sessionID = UUID()             // ① ユニークID

    var body: some View {
        QuizSession(mode: mode, onRetry: { sessionID = UUID() })  // ② リトライ時に新ID
            .id(sessionID)                             // ③ IDが変わると画面を再生成
    }
}
```

**ポイント**: `.id(sessionID)`は重要なテクニック。SwiftUIは`.id()`の値が変わると、そのViewを完全に破棄して新しく作り直します。これにより「もう一度」ボタンでクイズをリセットできます。

#### クイズセッション本体

```swift
private struct QuizSession: View {
    @EnvironmentObject private var store: ProgressStore
    @Environment(\.dismiss) private var dismiss          // ① 画面を閉じる機能
    @StateObject private var viewModel: QuizViewModel    // ② クイズのロジック
    @State private var savedResult = false
    let onRetry: () -> Void                              // ③ クロージャ（関数を受け取る）

    init(mode: QuizMode, onRetry: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: QuizViewModel(mode: mode))  // ④ StateObjectの初期化
        self.onRetry = onRetry
    }
```

**文法ポイント**:
- `@Environment(\.dismiss)`: SwiftUIが提供する「画面を閉じる」機能を取得
- `@escaping`: クロージャが関数の外で使われることを示す
- `_viewModel = StateObject(wrappedValue: ...)`: `@StateObject`を`init`内で初期化する方法

#### 変化の監視

```swift
        .onChange(of: viewModel.currentIndex) {          // ① 値の変化を監視
            if let q = viewModel.currentQuestion, q.mode == .audioToKana {
                KanaSpeaker.shared.speak(q.kanaPrompt, times: 3)
            }
        }
        .onChange(of: viewModel.isCompleted) {            // ② 完了時の処理
            guard viewModel.isCompleted, !savedResult else { return }
            let result = QuizSessionResult(
                id: UUID(),
                startedAt: viewModel.startedAt,
                endedAt: Date(),
                questionCount: viewModel.questionCount,
                correctCount: viewModel.correctCount,
                mode: viewModel.mode
            )
            store.saveSession(result)                    // ③ 結果を保存
            savedResult = true
        }
```

**文法ポイント**:
- `.onChange(of:)`: 指定した値が変化したときに処理を実行する
- `.onAppear`: 画面が表示されたときに1回実行される

### 7-5. QuizResultView.swift — クイズ結果画面

```swift
    private var starCount: Int {                         // ① 星の数を計算
        let ratio = Double(correctCount) / Double(max(questionCount, 1))
        switch ratio {                                   // ② switch文（範囲マッチング）
        case 1.0:        return 3                        // 全問正解 → 星3
        case 0.7..<1.0:  return 2                        // 70%以上 → 星2
        case 0.4..<0.7:  return 1                        // 40%以上 → 星1
        default:         return 0                        // それ以外 → 星0
        }
    }

    private var grade: (emoji: String, message: String, color: Color) {  // ③ タプル型
        switch starCount {
        case 3: return ("🌟", "かんぺき！\nすばらしい！", Color(...))
        case 2: return ("😄", "すごい！\nよくできたね！", Color(...))
        // ...
        }
    }
```

**文法ポイント**:
- `switch ratio { case 0.7..<1.0: }`: **範囲マッチング**。Swiftのswitch文は範囲で条件分岐できる
- `(emoji: String, message: String, color: Color)`: **名前付きタプル**。複数の値をまとめて返す

#### アニメーション

```swift
    .onAppear {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.55).delay(0.1)) {
            hanamaruScale = 1.0          // ① 花丸が大きくなるアニメ
            hanamaruRotation = 0         // ② 回転が戻るアニメ
        }
        withAnimation(.easeOut(duration: 0.5).delay(0.4)) {
            appeared = true              // ③ 0.4秒遅延して要素が表示される
        }
    }
```

### 7-6. LearningProgressView.swift — 進捗画面

```swift
    LazyVGrid(                                          // ① 遅延グリッド表示
        columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 5),  // ② 5列
        spacing: 10
    ) {
        ForEach(store.progressList(), id: \.self) { progress in
            KanaProgressCard(progress: progress)
        }
    }
```

**文法ポイント**:
- `LazyVGrid`: グリッド（格子状）レイアウト。`Lazy`なので画面に見える分だけ描画する
- `GridItem(.flexible())`: 柔軟な幅のグリッド列

### 7-7. ParentSettingsView.swift — 保護者向け設定

```swift
    SettingsToggleRow(
        label: "BGM",
        icon: "music.note",
        tint: Color(red: 0.38, green: 0.55, blue: 1.0),
        isOn: Binding(                                   // ① カスタムBinding
            get: { store.settings.bgmEnabled },          // ② 読み取り
            set: { newValue in                           // ③ 書き込み
                store.updateSettings { $0.bgmEnabled = newValue }
            }
        )
    )
```

**文法ポイント**:
- `Binding(get:set:)`: 読み取りと書き込みを別々に定義するカスタムバインディング
- `$0.bgmEnabled = newValue`: クロージャ内で`$0`（第1引数=inoutのAppSettings）のプロパティを変更

---

## 8. Swift基本文法まとめ

### 変数と定数

```swift
let name = "あいうえお"    // let = 定数（変更不可）
var count = 0              // var = 変数（変更可能）
count += 1                 // OK
// name = "かきくけこ"     // エラー！letは変更できない
```

### 型

```swift
let text: String = "あ"        // 文字列
let number: Int = 42           // 整数
let decimal: Double = 3.14     // 小数
let flag: Bool = true          // 真偽値
let items: [String] = ["あ"]   // 配列
let dict: [String: Int] = [:]  // 辞書
let maybe: String? = nil       // オプショナル（nilの可能性あり）
```

### 制御構文

```swift
// if文
if score >= 80 {
    print("よくできました")
} else if score >= 50 {
    print("がんばりました")
} else {
    print("もう一度")
}

// for文
for kana in KanaCatalog.hiragana {
    print(kana)
}

// guard文（条件を満たさなければ即リターン）
guard let value = optionalValue else { return }

// switch文
switch mode {
case .audioToKana: print("音→文字")
case .kanaToAudio: print("文字→音")
}
```

### 関数

```swift
func greet(_ name: String, times: Int = 1) -> String {
//    ↑名前  ↑_でラベル省略  ↑引数名: 型  ↑デフォルト値  ↑戻り値の型
    return "こんにちは、\(name)！"  // \() は文字列補間
}

greet("たろう")           // "こんにちは、たろう！"
greet("はなこ", times: 3) // デフォルト値を上書き
```

### クロージャ（無名関数）

```swift
// 正式な書き方
let doubled = [1, 2, 3].map({ (number: Int) -> Int in
    return number * 2
})

// 省略した書き方（よく使われる）
let doubled = [1, 2, 3].map { $0 * 2 }
// $0 は第1引数を表す省略記法
```

### struct vs class

```swift
struct Point {    // 値型（コピーされる）
    var x: Int
    var y: Int
}

class Person {    // 参照型（共有される）
    var name: String
    init(name: String) { self.name = name }
}
```

### SwiftUIの@マーク（プロパティラッパー）まとめ

| マーク | 用途 | 例え |
|---|---|---|
| `@State` | その画面だけの状態 | 自分のメモ帳 |
| `@Binding` | 親から受け取った状態（読み書き可） | 共有のメモ帳 |
| `@StateObject` | 自分が作ったObservableObject | 自分が買った掲示板 |
| `@ObservedObject` | 外から受け取ったObservableObject | もらった掲示板 |
| `@EnvironmentObject` | 親から環境経由で共有されたObject | クラスの掲示板 |
| `@Published` | 値が変わったら通知する | 掲示板の内容が変わったらベルが鳴る |
| `@Environment` | システムの設定値を取得 | 教室の時計を見る |

### データの流れ

```
AiueoLearningApp
  └─ @StateObject store = ProgressStore()  ← ここで作る
       │
       │  .environmentObject(store) で共有
       ▼
  ContentView → HomeView → StudyView / QuizView / ...
                             │
                   @EnvironmentObject var store  ← ここで受け取る
                             │
                   store.recordStudy(kana: "あ")  ← ここで使う
```

---

## 画面遷移の流れ

```
アプリ起動
  ↓
ContentView（NavigationStackの枠）
  ↓
HomeView（ホーム画面）
  ├── 「がくしゅう する」→ StudyView
  ├── 「クイズ する」   → QuizView → QuizResultView
  ├── 「しんちょく」    → LearningProgressView
  └── 「せってい」      → ParentSettingsView
```

---

これでアプリの全体構造とコードの意味がわかったと思います。
わからないところがあれば、具体的なファイル名や行番号を指定して質問してください！
