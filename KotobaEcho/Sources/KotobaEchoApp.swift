import SwiftUI

@main
struct KotobaEchoApp: App {
    @StateObject private var store = PhraseStore()

    var body: some Scene {
        WindowGroup {
            RootView(store: store)
        }
    }
}
