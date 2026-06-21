import SwiftUI

struct RootView: View {
    /// store は environment ではなく明示的に渡す。
    /// 各画面が @StateObject の ViewModel を store から正しく初期化できるようにするため。
    let store: PhraseStore

    var body: some View {
        TabView {
            ListenView(store: store)
                .tabItem { Label("きく", systemImage: "ear") }

            RegisterView(store: store)
                .tabItem { Label("とうろく", systemImage: "mic.badge.plus") }

            PhraseListView(store: store)
                .tabItem { Label("じしょ", systemImage: "book") }

            SettingsView(store: store)
                .tabItem { Label("せってい", systemImage: "gearshape") }
        }
    }
}
