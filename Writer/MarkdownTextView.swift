import SwiftUI
import UIKit

/// UITextView with live markdown highlighting — the iOS counterpart to
/// writer-computer's CodeMirror/prosemark editor. TextKit 1 for direct
/// NSTextStorage access.
struct MarkdownTextView: UIViewRepresentable {
    @Binding var text: String
    @ObservedObject var formatter: EditorFormatter

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> UITextView {
        // TextKit 1 keeps layout/highlighting in the classic pipeline.
        let tv = UITextView(usingTextLayoutManager: false)
        tv.delegate = context.coordinator
        tv.backgroundColor = .clear
        tv.textColor = WriterTheme.foregroundUI
        tv.tintColor = WriterTheme.accentUI
        tv.font = .systemFont(ofSize: WriterTheme.editorFontSize)
        tv.typingAttributes = MarkdownHighlighter.baseAttributes
        tv.textContainerInset = UIEdgeInsets(top: 16, left: 16, bottom: 60, right: 16)
        tv.keyboardDismissMode = .interactive
        tv.alwaysBounceVertical = true
        tv.autocapitalizationType = .sentences
        tv.smartQuotesType = .no
        tv.smartDashesType = .no
        tv.inputAccessoryView = MarkdownAccessoryBar(formatter: formatter)
        formatter.textView = tv
        tv.text = text
        MarkdownHighlighter.highlight(tv.textStorage)
        return tv
    }

    func updateUIView(_ tv: UITextView, context: Context) {
        formatter.textView = tv
        guard tv.text != text else { return }
        let sel = tv.selectedRange
        tv.text = text
        MarkdownHighlighter.highlight(tv.textStorage)
        tv.selectedRange = sel.clamped(to: tv.text.count)
        tv.typingAttributes = MarkdownHighlighter.baseAttributes
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: MarkdownTextView

        init(_ parent: MarkdownTextView) { self.parent = parent }

        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
            // Don't restyle while IME/marked text is composing.
            guard textView.markedTextRange == nil else { return }
            MarkdownHighlighter.highlight(textView.textStorage)
            textView.typingAttributes = MarkdownHighlighter.baseAttributes
        }

        /// Return-key list continuation: "- item↩" inserts "- ", and
        /// pressing return on an empty marker line drops the marker.
        func textView(
            _ textView: UITextView,
            shouldChangeTextIn range: NSRange,
            replacementText text: String
        ) -> Bool {
            guard text == "\n" else { return true }
            let nsText = textView.text as NSString
            let lineRange = nsText.lineRange(for: range)
            let line = nsText.substring(with: lineRange)

            guard let marker = Self.listPrefix(of: line) else { return true }

            if line.trimmingCharacters(in: .whitespacesAndNewlines) == marker.trimmingCharacters(in: .whitespaces) {
                // Empty item — remove the marker, don't continue the list.
                textView.textStorage.replaceCharacters(in: lineRange, with: "")
                textView.selectedRange = NSRange(location: lineRange.location, length: 0)
                textView.delegate?.textViewDidChange?(textView)
                return false
            }

            // Numbered lists continue with the next number; other markers
            // repeat verbatim.
            let insertion: String
            let digits = marker.prefix(while: { $0.isNumber })
            if !digits.isEmpty {
                let num = (Int(digits) ?? 0) + 1
                let delim = marker.contains(")") ? ")" : "."
                insertion = "\(num)\(delim) "
            } else if marker.contains("[x]") || marker.contains("[X]") {
                // Continuing from a checked task starts a fresh unchecked one.
                insertion = marker.replacingOccurrences(
                    of: "[x]", with: "[ ]").replacingOccurrences(of: "[X]", with: "[ ]")
            } else {
                insertion = marker
            }

            let indent = line.prefix(while: { $0 == " " })
            let replacement = "\n" + String(indent) + insertion
            textView.textStorage.replaceCharacters(in: range, with: replacement)
            textView.selectedRange = NSRange(
                location: range.location + replacement.count, length: 0)
            textView.delegate?.textViewDidChange?(textView)
            return false
        }

        /// The repeatable marker at the start of a list/task/quote line.
        private static func listPrefix(of line: String) -> String? {
            let trimmed = line.drop(while: { $0 == " " })
            for marker in ["- [ ] ", "- [x] ", "- [X] ", "- ", "* ", "+ ", "> "] {
                if trimmed.hasPrefix(marker) { return marker }
            }
            if let m = trimmed.range(of: #"^\d+[.)]\s"#, options: .regularExpression) {
                return String(trimmed[m])
            }
            return nil
        }
    }
}

private extension NSRange {
    func clamped(to length: Int) -> NSRange {
        NSRange(location: min(location, length), length: min(self.length, max(0, length - location)))
    }
}
