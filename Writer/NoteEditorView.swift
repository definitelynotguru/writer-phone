import SwiftUI

struct NoteEditorView: View {
    @EnvironmentObject var store: NoteStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    @State private var note: Note
    @State private var text: String
    @State private var lastSaved: String
    @State private var isPreview = false
    @State private var showRename = false
    @State private var showDeleteConfirm = false
    @State private var newTitle = ""
    @State private var saveError = false
    @StateObject private var formatter = EditorFormatter()

    init(note: Note) {
        _note = State(initialValue: note)
        _text = State(initialValue: note.content)
        _lastSaved = State(initialValue: note.content)
    }

    var body: some View {
        VStack(spacing: 0) {
            if isPreview {
                MarkdownPreview(text: text) { lineIndex in
                    let (_, lines) = MarkdownParser.parse(text)
                    text = MarkdownParser.toggledTaskLine(lines, at: lineIndex)
                }
            } else {
                MarkdownTextView(text: $text, formatter: formatter)
            }
            statsBar
        }
        .background(WriterTheme.background.ignoresSafeArea())
        .navigationTitle(note.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isPreview.toggle()
                    if !isPreview { formatter.textView?.becomeFirstResponder() }
                } label: {
                    Image(systemName: isPreview ? "pencil" : "eye")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    ShareLink(item: note.url) {
                        Label("Share File", systemImage: "square.and.arrow.up")
                    }
                    Button { newTitle = note.title; showRename = true } label: {
                        Label("Rename", systemImage: "pencil.line")
                    }
                    Button { _ = store.duplicate(note); store.scan() } label: {
                        Label("Duplicate", systemImage: "doc.on.doc")
                    }
                    Divider()
                    Button(role: .destructive) { showDeleteConfirm = true } label: {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .alert("Rename Note", isPresented: $showRename) {
            TextField("Title", text: $newTitle)
            Button("Cancel", role: .cancel) {}
            Button("Rename") {
                if let renamed = store.rename(note, to: newTitle) {
                    note = renamed
                }
            }
        }
        .alert("Delete “\(note.title)”?", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                store.delete(note)
                dismiss()
            }
        } message: {
            Text("This permanently removes the markdown file.")
        }
        .alert("Couldn't Save", isPresented: $saveError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("The note file could not be written to disk.")
        }
        .onChange(of: text) { _, _ in scheduleSave() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { reloadIfChangedExternally() }
        }
        .onAppear {
            // Something may have changed while the list was up.
            reloadIfChangedExternally()
        }
    }

    // MARK: - Stats bar (mirrors the desktop's "N words · N chars · N paragraphs")

    private var stats: (words: Int, chars: Int, paragraphs: Int) {
        let words = text.split { $0 == " " || $0 == "\n" || $0 == "\t" }.count
        let paras = text.split(separator: /\n\s*\n/)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .count
        return (words, text.count, text.isEmpty ? 0 : paras)
    }

    private var statsBar: some View {
        HStack {
            Spacer()
            Text("\(stats.words) words · \(stats.chars) characters · \(stats.paragraphs) paragraphs")
                .font(.system(size: 12))
                .foregroundStyle(WriterTheme.muted)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(WriterTheme.card.opacity(0.5))
    }

    // MARK: - Saving

    @State private var saveBox = SaveBox()

    private func scheduleSave() {
        saveBox.task?.cancel()
        saveBox.task = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }
            guard text != lastSaved else { return }
            if store.save(note, text: text) {
                lastSaved = text
            } else {
                saveError = true
            }
        }
    }

    /// Re-reads the file and updates the editor only when nothing typed
    /// since the last save would be clobbered (last write wins otherwise).
    private func reloadIfChangedExternally() {
        guard text == lastSaved,
              let onDisk = try? String(contentsOf: note.url, encoding: .utf8),
              onDisk != lastSaved
        else { return }
        text = onDisk
        lastSaved = onDisk
    }

    private final class SaveBox {
        var task: Task<Void, Never>?
    }
}
