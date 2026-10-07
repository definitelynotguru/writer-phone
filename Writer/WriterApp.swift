import SwiftUI

@main
struct WriterApp: App {
    @StateObject private var store = NoteStore()

    var body: some Scene {
        WindowGroup {
            NotesListView()
                .environmentObject(store)
                .tint(WriterTheme.accent)
        }
    }
}
