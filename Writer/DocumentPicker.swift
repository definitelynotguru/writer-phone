import SwiftUI
import UniformTypeIdentifiers

/// System file picker for importing `.md`/`.txt` files into the notes list.
struct DocumentPicker: UIViewControllerRepresentable {
    var onPick: ([URL]) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        var types: [UTType] = [.plainText, .text, .utf8PlainText]
        if let md = UTType("net.daringfireball.markdown") { types.insert(md, at: 0) }
        let vc = UIDocumentPickerViewController(forOpeningContentTypes: types, asCopy: true)
        vc.allowsMultipleSelection = true
        vc.shouldShowFileExtensions = true
        vc.delegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: ([URL]) -> Void
        init(onPick: @escaping ([URL]) -> Void) { self.onPick = onPick }
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            onPick(urls)
        }
    }
}
