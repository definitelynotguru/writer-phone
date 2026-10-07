import SwiftUI

@main
struct WriterApp: App {
    @StateObject private var store = NoteStore()

    var body: some Scene {
        WindowGroup {
            TabView {
                NotesListView()
                    .tabItem { Label("Notes", systemImage: "doc.text") }
                IntroductionView()
                    .tabItem { Label("Introduction", systemImage: "number") }
            }
            .environmentObject(store)
            .tint(WriterTheme.accent)
        }
    }
}
