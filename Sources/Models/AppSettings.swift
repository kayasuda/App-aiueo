import Foundation

struct AppSettings: Codable {
    var bgmEnabled: Bool = true
    var sfxEnabled: Bool = true
    var dailyGoalMinutes: Int = 10
    var purchased: Bool = true
}

