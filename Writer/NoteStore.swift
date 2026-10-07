import Foundation

/// A note is a plain `.md` file in the app's Documents directory, visible in
/// the iOS Files app — same "documents on disk" model as writer-computer.
struct Note: Identifiable, Hashable {
    let url: URL
    var title: String
    var modified: Date
    var preview: String
    var content: String

    var id: URL { url }

    /// Identity is the file itself — content/modified mutate with saves.
    static func == (lhs: Note, rhs: Note) -> Bool { lhs.url == rhs.url }
    func hash(into hasher: inout Hasher) { hasher.combine(url) }
}

final class NoteStore: ObservableObject {
    @Published private(set) var notes: [Note] = []

    private let fileManager = FileManager.default

    var directory: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    /// Re-reads all .md files from Documents. Cheap at notes-app scale.
    func scan() {
        let urls = (try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )) ?? []

        let scanned: [Note] = urls
            .filter { $0.pathExtension.lowercased() == "md" }
            .compactMap { url in
                guard let content = try? String(contentsOf: url, encoding: .utf8) else {
                    return nil
                }
                let modified =
                    (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?
                    .contentModificationDate ?? .distantPast
                return Note(
                    url: url,
                    title: url.deletingPathExtension().lastPathComponent,
                    modified: modified,
                    preview: Self.makePreview(of: content),
                    content: content
                )
            }
        notes = scanned.sorted { $0.modified > $1.modified }
    }

    @discardableResult
    func create() -> Note {
        var title = "Untitled"
        var url = fileURL(for: title)
        var n = 2
        while fileManager.fileExists(atPath: url.path) {
            title = "Untitled \(n)"
            url = fileURL(for: title)
            n += 1
        }
        try? "".write(to: url, atomically: true, encoding: .utf8)
        scan()
        return notes.first { $0.url == url }
            ?? Note(url: url, title: title, modified: Date(), preview: "", content: "")
    }

    /// Writes the file and refreshes the in-memory copy. Returns false on IO error.
    @discardableResult
    func save(_ note: Note, text: String) -> Bool {
        do {
            try text.write(to: note.url, atomically: true, encoding: .utf8)
        } catch {
            return false
        }
        guard let i = notes.firstIndex(of: note) else { return true }
        notes[i].content = text
        notes[i].modified = Date()
        notes[i].preview = Self.makePreview(of: text)
        return true
    }

    /// Renames the underlying file and returns the renamed note. `title`
    /// maps to `<title>.md`; rejects collisions, empty names, and separators.
    @discardableResult
    func rename(_ note: Note, to title: String) -> Note? {
        let clean = sanitize(title)
        guard !clean.isEmpty, clean != note.title else { return nil }
        let dest = fileURL(for: clean)
        guard !fileManager.fileExists(atPath: dest.path) else { return nil }
        do {
            try fileManager.moveItem(at: note.url, to: dest)
        } catch {
            return nil
        }
        scan()
        return notes.first { $0.url == dest }
    }

    func delete(_ note: Note) {
        try? fileManager.removeItem(at: note.url)
        notes.removeAll { $0 == note }
    }

    @discardableResult
    func duplicate(_ note: Note) -> Note? {
        var title = "\(note.title) copy"
        var url = fileURL(for: title)
        var n = 2
        while fileManager.fileExists(atPath: url.path) {
            title = "\(note.title) copy \(n)"
            url = fileURL(for: title)
            n += 1
        }
        guard (try? fileManager.copyItem(at: note.url, to: url)) != nil else { return nil }
        scan()
        return notes.first { $0.url == url }
    }

    func matching(_ query: String) -> [Note] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return notes }
        let needle = q.lowercased()
        return notes.filter {
            $0.title.lowercased().contains(needle)
                || $0.content.lowercased().contains(needle)
        }
    }

    private func fileURL(for title: String) -> URL {
        directory.appendingPathComponent(title).appendingPathExtension("md")
    }

    private func sanitize(_ title: String) -> String {
        title
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
    }

    /// First ~140 visible chars: markdown markers stripped, lines joined.
    static func makePreview(of text: String) -> String {
        var out = ""
        for raw in text.split(separator: "\n", omittingEmptySubsequences: true) {
            var line = raw.trimmingCharacters(in: .whitespaces)
            if line.isEmpty { continue }
            while let first = line.first, "#>*-".contains(first) || first == " " {
                line = String(line.dropFirst()).trimmingCharacters(in: .whitespaces)
                if line.hasPrefix("[ ]") || line.hasPrefix("[x]") || line.hasPrefix("[X]") {
                    line = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                }
            }
            if line.isEmpty || line.allSatisfy({ $0 == "-" || $0 == "*" || $0 == " " }) {
                continue
            }
            out += (out.isEmpty ? "" : " ") + line
            if out.count > 140 { break }
        }
        return String(out.prefix(140))
    }
}
