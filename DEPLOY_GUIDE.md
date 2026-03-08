# iPad向け「あいうえおアプリ」初心者デプロイガイド

最終確認日: 2026-03-01（JST）

このガイドは、`SwiftUI` で作った iPad アプリを App Store に公開するまでの最短ルートです。

## 0. 全体の流れ

1. Apple Developer Program に加入
2. Xcode で配布設定（Bundle ID / バージョン）
3. 実機テストして Archive を作成
4. App Store Connect でアプリ情報を入力
5. TestFlight で最終確認
6. App Review に提出
7. 承認後に公開（自動 or 手動）

## 1. 事前準備（最初に必要）

### 1-1. Apple Developer Program への加入

- 年額 99 USD（地域により現地通貨表示）
- 加入しないと App Store 配布はできません

### 1-2. 必要なアカウント権限

- App Store Connect で提出するには、少なくとも `App Manager` 以上の権限が必要

## 2. Xcode 側の設定

### 2-1. Signing & Capabilities

- `Signing` を `Automatically manage signing` にする（初心者はこれが安全）
- `Team` に自分の開発者アカウントを選ぶ

### 2-2. Bundle Identifier

- 例: `com.yourname.aiueoapp`
- 既存アプリと重複しない一意の ID が必要

### 2-3. バージョン番号

- `Version`（例: `1.0.0`）: ユーザー向け
- `Build`（例: `1`）: アップロードごとに増やす

### 2-4. iPad 対応確認

- iPad 専用なら `iPad` をサポート対象に含める
- 画面崩れがないか、実機で確認

## 3. 初回アップロード（Archive）

1. Xcode 上部で `Any iOS Device (arm64)` を選ぶ  
2. `Product > Archive`  
3. Organizer が開いたら `Distribute App`  
4. `App Store Connect` を選択してアップロード  
5. App Store Connect 側で「Processing」が終わるまで待つ（メール通知あり）

## 4. App Store Connect の入力（重要）

### 4-1. アプリレコード作成

- App Store Connect > `My Apps` > `+` > `New App`
- ここで Bundle ID を紐付ける

### 4-2. 必須メタデータ

- アプリ名、サブタイトル、説明文
- キーワード
- サポート URL
- プライバシーポリシー URL
- 年齢レーティング（子ども向けなら特に慎重に）

### 4-3. スクリーンショット

- iPad で動くアプリは iPad 用スクリーンショットが必須
- 1〜10枚、`png/jpg/jpeg`

### 4-4. App Privacy（プライバシーラベル）

- 収集データの有無を申告（SDK 含む）
- これを入力しないと提出できません

### 4-5. 買い切り価格の設定

- `Pricing and Availability` で価格を設定
- 有料アプリにするには `Paid Apps Agreement` の同意が必要

## 5. TestFlight（公開前の最終チェック）

### 5-1. Internal Test（まずこれ）

- チーム内テスター（最大100人）で確認
- クラッシュ、音声、課金状態表示、iPad UI を重点確認

### 5-2. External Test（必要なら）

- 外部テスター（最大10,000人）で実利用に近い確認
- 公開リンク配布も可能

## 6. App Review 提出

1. 対象バージョンでビルドを選択  
2. `Add for Review`  
3. `Submit for Review`

提出前チェック:

- アプリがクラッシュしない
- ダミー文言が残っていない
- プライバシー情報が実装と一致
- 子ども向けとして不適切な外部リンクや導線がない

## 7. 承認後の公開

- 自動公開: 承認後すぐ配信
- 手動公開: 自分のタイミングで配信開始

公開後、全ストアに反映されるまで最大24時間程度かかることがあります。

## 8. よくある詰まりポイント

- `Build` 番号を上げずに再アップロードして失敗
- Privacy URL 未設定で提出不可
- Paid Apps Agreement 未同意で有料設定不可
- iPad スクリーンショット不足で差し戻し
- App Review 用の説明不足（ログイン必要アプリでデモ情報未記載等）

## 9. 2026年の注意点（重要）

- 2026-04-28 以降、iOS / iPadOS アプリは **iOS & iPadOS 26 SDK 以上**でビルドが必要（Apple案内）
- 年齢レーティング制度が更新されており、2026-01-31 までに新しい質問への回答が必要（未対応だと更新提出時に影響）
- 提出前に Xcode バージョン要件を毎回確認してください

## 10. このアプリ向けの提出前チェックリスト

- [ ] iPad で縦画面 UI が崩れない
- [ ] 46文字すべてで学習/クイズが動く
- [ ] 進捗保存（再起動後復元）が動く
- [ ] BGM/効果音の設定が保存される
- [ ] 課金モデル説明が「買い切り」と一致
- [ ] プライバシーポリシー URL を設定済み
- [ ] iPad スクショを必要枚数アップロード済み
- [ ] 価格設定と Paid Apps Agreement を確認済み

---

## 参考リンク（Apple公式）

- Apple Developer Program 登録: https://developer.apple.com/programs/enroll/
- App Store Connect: https://developer.apple.com/app-store-connect/
- アプリ提出手順: https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/submit-an-app
- ビルドアップロード: https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds/
- スクリーンショット仕様: https://developer.apple.com/help/app-store-connect/reference/screenshot-specifications
- App Privacy: https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy/
- 価格設定: https://developer.apple.com/help/app-store-connect/manage-app-pricing/set-a-price/
- App Review Guidelines: https://developer.apple.com/app-store/review/guidelines/
- 提出ポータル（最新要件）: https://developer.apple.com/app-store/submitting/
