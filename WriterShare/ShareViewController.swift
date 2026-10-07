import Social
import UniformTypeIdentifiers

/// "Share → Writer": receives text (e.g. a shared Apple Notes or Journal
/// entry) and saves it as a `.md` file in the app group's Inbox. The main
/// app imports it on next activation. Uses the standard compose card so the
/// shared text can be edited before saving.
final class ShareViewController: SLComposeServiceViewController {
    static let appGroupID = "group.com.writer-phone"

    override func isContentValid() -> Bool { true }

    override func didSelectPost() {
        let edited = contentText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !edited.isEmpty {
            save(edited)
            return
        }
        loadAttachments { [self] texts in
            save(texts.joined(separator: "\n\n"))
        }
    }

    /// Pulls text/url payloads out of the extension context, e.g. when the
    /// source app attached the note instead of prefilling the composer.
    private func loadAttachments(_ done: @escaping ([String]) -> Void) {
        var texts: [String] = []
        let group = DispatchGroup()
        let items = (extensionContext?.inputItems as? [NSExtensionItem]) ?? []
        for item in items {
            for provider in item.attachments ?? [] {
                for type in [UTType.plainText, UTType.text, UTType.url] where provider.hasItemConformingToTypeIdentifier(type.identifier) {
                    group.enter()
                    provider.loadItem(forTypeIdentifier: type.identifier) { obj, _ in
                        if let url = obj as? URL { texts.append(url.absoluteString) }
                        else if let str = obj as? String { texts.append(str) }
                        group.leave()
                    }
                    break
                }
            }
        }
        group.notify(queue: .main) { done(texts) }
    }

    private func save(_ body: String) {
        defer { extensionContext?.completeRequest(returningItems: []) }
        let text = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty,
              let container = FileManager.default
                .containerURL(forSecurityApplicationGroupIdentifier: Self.appGroupID)
        else { return }
        let inbox = container.appendingPathComponent("Inbox", isDirectory: true)
        try? FileManager.default.createDirectory(at: inbox, withIntermediateDirectories: true)
        let filename = "\(Self.sanitize(Self.title(from: text)))-\(Int(Date().timeIntervalSince1970)).md"
        try? text.write(
            to: inbox.appendingPathComponent(filename),
            atomically: true, encoding: .utf8
        )
    }

    /// Title = first non-empty line, markdown markers stripped.
    static func title(from text: String) -> String {
        for raw in text.split(separator: "\n") {
            var line = raw.trimmingCharacters(in: .whitespaces)
            while line.hasPrefix("#") || line.hasPrefix(">") || line.hasPrefix("-") {
                line = String(line.dropFirst()).trimmingCharacters(in: .whitespaces)
            }
            if !line.isEmpty { return String(line.prefix(60)) }
        }
        return "Shared"
    }

    static func sanitize(_ title: String) -> String {
        let clean = title
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return clean.isEmpty ? "Shared" : clean
    }
}
