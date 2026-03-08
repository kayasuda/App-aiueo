# Aiueo iPad App MVP Blueprint

This workspace contains a SwiftUI implementation blueprint for:

- Target age: 4-6
- Scope: Hiragana only (46 chars)
- Monetization: One-time purchase
- Design: Simple educational

## Screen map

- Home
- Study
- Quiz
- Result
- Progress
- Parent Settings

## Persistence

- `UserDefaults` + JSON via `ProgressStore`
- Settings, per-kana progress, and recent quiz session history (max 30)

## Suggested integration

1. Add files under your Xcode app target.
2. Set `AiueoLearningApp` as the app entry or merge into your existing `@main`.
3. Connect audio playback where the UI has placeholder actions.

