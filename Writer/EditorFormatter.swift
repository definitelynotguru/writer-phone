import UIKit

/// Actions the keyboard markdown bar performs on the live UITextView.
/// Owned by NoteEditorView; MarkdownTextView wires `textView` in.
final class EditorFormatter: ObservableObject {
    weak var textView: UITextView?

    private func commit(_ mutate: (UITextView) -> Void) {
        guard let tv = textView else { return }
        mutate(tv)
        // Manual textStorage edits don't fire didChange — run the same path
        // so the binding updates and highlighting re-applies.
        tv.delegate?.textViewDidChange?(tv)
    }

    private func lineRange(in tv: UITextView) -> NSRange {
        (tv.text as NSString).lineRange(for: tv.selectedRange)
    }

    /// Toggles/sets an ATX heading prefix on the current line.
    func heading() {
        commit { tv in
            let nsText = tv.text as NSString
            let lr = lineRange(in: tv)
            let line = nsText.substring(with: lr)
            var newLine = line
            if let m = line.range(of: #"^#{1,6}\s"#, options: .regularExpression) {
                newLine.removeSubrange(m)
            } else {
                newLine = "# " + line
            }
            let delta = newLine.count - line.count
            tv.textStorage.replaceCharacters(in: lr, with: newLine)
            tv.selectedRange = NSRange(
                location: max(0, tv.selectedRange.location + delta), length: 0)
        }
    }

    /// Toggles an unordered list marker on the current line.
    func bullet() {
        toggleLinePrefix("- ")
    }

    /// Toggles a task item marker on the current line.
    func task() {
        toggleLinePrefix("- [ ] ")
    }

    /// Toggles a blockquote marker on the current line.
    func quote() {
        toggleLinePrefix("> ")
    }

    private func toggleLinePrefix(_ prefix: String) {
        commit { tv in
            let nsText = tv.text as NSString
            let lr = lineRange(in: tv)
            let line = nsText.substring(with: lr)
            var newLine = line
            if line.hasPrefix(prefix) {
                newLine.removeFirst(prefix.count)
            } else {
                newLine = prefix + line
            }
            let delta = newLine.count - line.count
            tv.textStorage.replaceCharacters(in: lr, with: newLine)
            tv.selectedRange = NSRange(
                location: max(0, tv.selectedRange.location + delta), length: 0)
        }
    }

    /// Wraps the selection (or inserts a marker pair at the caret).
    func wrap(_ marker: String) {
        commit { tv in
            let sel = tv.selectedRange
            guard sel.location != NSNotFound else { return }
            if sel.length > 0 {
                let selected = (tv.text as NSString).substring(with: sel)
                // Toggle off if already wrapped.
                if selected.hasPrefix(marker), selected.hasSuffix(marker),
                   selected.count > marker.count * 2 {
                    let inner = String(selected.dropFirst(marker.count).dropLast(marker.count))
                    tv.textStorage.replaceCharacters(in: sel, with: inner)
                    tv.selectedRange = NSRange(location: sel.location, length: inner.count)
                } else {
                    let wrapped = marker + selected + marker
                    tv.textStorage.replaceCharacters(in: sel, with: wrapped)
                    tv.selectedRange = NSRange(
                        location: sel.location + marker.count, length: sel.length)
                }
            } else {
                let pair = marker + marker
                tv.textStorage.replaceCharacters(in: sel, with: pair)
                tv.selectedRange = NSRange(location: sel.location + marker.count, length: 0)
            }
        }
    }
}
