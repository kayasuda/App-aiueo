import SwiftUI

struct ParentSettingsView: View {
    @EnvironmentObject private var store: ProgressStore

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                SettingsCard(title: "🔊 サウンド") {
                    VStack(spacing: 0) {
                        SettingsToggleRow(
                            label: "BGM",
                            icon: "music.note",
                            tint: Color(red: 0.38, green: 0.55, blue: 1.0),
                            isOn: Binding(
                                get: { store.settings.bgmEnabled },
                                set: { newValue in store.updateSettings { $0.bgmEnabled = newValue } }
                            )
                        )
                        Divider().padding(.leading, 56)
                        SettingsToggleRow(
                            label: "こうかおん",
                            icon: "bell.fill",
                            tint: Color(red: 0.38, green: 0.55, blue: 1.0),
                            isOn: Binding(
                                get: { store.settings.sfxEnabled },
                                set: { newValue in store.updateSettings { $0.sfxEnabled = newValue } }
                            )
                        )
                    }
                }

                SettingsCard(title: "🎯 がくしゅうもくひょう") {
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(Color(red: 0.5, green: 0.28, blue: 0.92).opacity(0.12))
                                .frame(width: 36, height: 36)
                            Image(systemName: "clock.fill")
                                .foregroundStyle(Color(red: 0.5, green: 0.28, blue: 0.92))
                        }
                        Text("1にち \(store.settings.dailyGoalMinutes) ふん")
                            .font(.body.bold())
                        Spacer()
                        Stepper(
                            "",
                            value: Binding(
                                get: { store.settings.dailyGoalMinutes },
                                set: { newValue in store.updateSettings { $0.dailyGoalMinutes = newValue } }
                            ),
                            in: 5...30,
                            step: 5
                        )
                        .labelsHidden()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }

                SettingsCard(title: "👀 しゅうちゅうど みまもり") {
                    VStack(spacing: 0) {
                        SettingsToggleRow(
                            label: "みまもり ON/OFF",
                            icon: "eye.fill",
                            tint: Color(red: 0.9, green: 0.45, blue: 0.2),
                            isOn: Binding(
                                get: { store.settings.concentrationMonitorEnabled },
                                set: { newValue in store.updateSettings { $0.concentrationMonitorEnabled = newValue } }
                            )
                        )
                        Divider().padding(.leading, 56)
                        HStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(Color(red: 0.9, green: 0.45, blue: 0.2).opacity(0.12))
                                    .frame(width: 36, height: 36)
                                Image(systemName: "key.fill")
                                    .foregroundStyle(Color(red: 0.9, green: 0.45, blue: 0.2))
                                    .font(.system(size: 15, weight: .semibold))
                            }
                            VStack(alignment: .leading, spacing: 4) {
                                Text("API キー")
                                    .font(.body.bold())
                                SecureField("sk-ant-...", text: Binding(
                                    get: { store.settings.anthropicAPIKey },
                                    set: { newValue in store.updateSettings { $0.anthropicAPIKey = newValue } }
                                ))
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 14, design: .monospaced))
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)

                        Text("クイズ中にカメラで30秒ごとに集中度をチェックし、声かけします。Anthropic の API キーが必要です。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 12)
                    }
                }

                SettingsCard(title: "💎 こうにゅうじょうたい") {
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill((store.settings.purchased ? Color.green : Color.orange).opacity(0.12))
                                .frame(width: 36, height: 36)
                            Image(systemName: store.settings.purchased ? "checkmark.seal.fill" : "lock.fill")
                                .foregroundStyle(store.settings.purchased ? Color.green : Color.orange)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("かきんモデル")
                                .font(.body.bold())
                            Text(store.settings.purchased ? "かいきり かいほうずみ" : "みこうにゅう")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }
            }
            .padding(20)
        }
        .background(Color(red: 0.96, green: 0.96, blue: 0.98).ignoresSafeArea())
        .navigationTitle("ほごしゃ むけ")
        .navigationBarTitleDisplayMode(.large)
    }
}

private struct SettingsCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 10)

            content()
                .padding(.bottom, 6)
        }
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 5)
    }
}

private struct SettingsToggleRow: View {
    let label: String
    let icon: String
    let tint: Color
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(tint.opacity(0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .foregroundStyle(tint)
                    .font(.system(size: 15, weight: .semibold))
            }
            Text(label)
                .font(.body.bold())
            Spacer()
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(tint)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

#Preview {
    NavigationStack {
        ParentSettingsView()
            .environmentObject(ProgressStore())
    }
}
