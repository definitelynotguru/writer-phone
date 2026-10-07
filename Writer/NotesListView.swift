import SwiftUI

struct NotesListView: View {
    @EnvironmentObject var store: NoteStore
    @Environment(\.scenePhase) private var scenePhase
    @State private var query = ""
    @State private var showAbout = false
    @State private var renaming: Note?
    @State private var renameText = ""
    @State private var path = NavigationPath()

    private var filtered: [Note] { store.matching(query) }

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if filtered.isEmpty {
                    emptyState
                } else {
                    notesList
                }
            }
            .navigationTitle("Writer")
            .searchable(text: $query, prompt: "Search notes")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showAbout = true } label: {
                        Image(systemName: "info.circle")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { newNote() } label: {
                        Image(systemName: "square.and.pencil")
                    }
                }
            }
            .navigationDestination(for: Note.self) { note in
                NoteEditorView(note: note)
            }
        }
        .sheet(isPresented: $showAbout) { AboutView() }
        .alert("Rename Note", isPresented: renameBinding) {
            TextField("Title", text: $renameText)
            Button("Cancel", role: .cancel) {}
            Button("Rename") {
                if let note = renaming {
                    _ = store.rename(note, to: renameText)
                }
            }
        }
        .onAppear { store.scan() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { store.scan() }
        }
    }

    private var notesList: some View {
        List(filtered) { note in
            NavigationLink(value: note) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(note.title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(WriterTheme.foreground)
                        .lineLimit(1)
                    if !note.preview.isEmpty {
                        Text(note.preview)
                            .font(.system(size: 14))
                            .foregroundStyle(WriterTheme.muted)
                            .lineLimit(2)
                    }
                    Text(note.modified, style: .date)
                        .font(.system(size: 12))
                        .foregroundStyle(WriterTheme.muted.opacity(0.7))
                }
                .padding(.vertical, 4)
            }
            .listRowBackground(WriterTheme.background)
            .swipeActions(edge: .trailing) {
                Button(role: .destructive) {
                    store.delete(note)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                Button {
                    renaming = note
                    renameText = note.title
                } label: {
                    Label("Rename", systemImage: "pencil.line")
                }
                .tint(WriterTheme.accent)
            }
            .contextMenu {
                Button {
                    renaming = note
                    renameText = note.title
                } label: {
                    Label("Rename", systemImage: "pencil.line")
                }
                Button {
                    _ = store.duplicate(note)
                } label: {
                    Label("Duplicate", systemImage: "doc.on.doc")
                }
                ShareLink(item: note.url) {
                    Label("Share File", systemImage: "square.and.arrow.up")
                }
                Divider()
                Button(role: .destructive) {
                    store.delete(note)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(WriterTheme.background)
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Notes", systemImage: "doc.text")
        } description: {
            Text(query.isEmpty
                 ? "Tap the compose button to write your first note."
                 : "No notes match “\(query)”.")
        } actions: {
            if query.isEmpty {
                Button("New Note") { newNote() }
                    .buttonStyle(.borderedProminent)
            }
        }
    }

    private var renameBinding: Binding<Bool> {
        Binding(
            get: { renaming != nil },
            set: { if !$0 { renaming = nil } }
        )
    }

    private func newNote() {
        let note = store.create()
        path.append(note)
    }
}
