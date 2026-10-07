import UIKit

/// Applies Writer's inline markdown styling to an NSTextStorage: headings,
/// fenced code, lists/tasks, quotes, rules, and inline bold/italic/code/
/// strikethrough/links. Syntax markers render dimmed, like prosemark.
enum MarkdownHighlighter {

    private static let boldRegex = try! NSRegularExpression(
        pattern: #"\*\*[^*\n]+?\*\*|__[^_\n]+?__"#)
    private static let italicRegex = try! NSRegularExpression(
        pattern: #"(?<![\*\w])\*[^*\n]+?\*(?!\*)|(?<![_\w])_[^_\n]+?_(?!\w)"#)
    private static let codeRegex = try! NSRegularExpression(
        pattern: #"`[^`\n]+?`"#)
    private static let strikeRegex = try! NSRegularExpression(
        pattern: #"~~[^~\n]+?~~"#)
    private static let linkRegex = try! NSRegularExpression(
        pattern: #"\[([^\]\n]+)\]\(([^)\s]+)\)"#)

    private static var baseFont: UIFont {
        UIFont.systemFont(ofSize: WriterTheme.editorFontSize)
    }

    private static var baseParagraph: NSParagraphStyle {
        let p = NSMutableParagraphStyle()
        p.lineSpacing = WriterTheme.editorLineSpacing
        return p
    }

    static var baseAttributes: [NSAttributedString.Key: Any] {
        [
            .font: baseFont,
            .foregroundColor: WriterTheme.foregroundUI,
            .paragraphStyle: baseParagraph,
        ]
    }

    private static func headingFont(_ level: Int) -> UIFont {
        let sizes: [CGFloat] = [30, 25, 21, 18, 17, 16]
        let size = sizes[max(0, min(level - 1, sizes.count - 1))]
        return UIFont.boldSystemFont(ofSize: size)
    }

    /// Attributes-only pass — never touches the text, so the cursor stays put.
    static func highlight(_ storage: NSTextStorage) {
        let full = NSRange(location: 0, length: storage.length)
        let text = storage.string as NSString

        storage.beginEditing()
        storage.setAttributes(baseAttributes, range: full)
        storage.removeAttribute(.backgroundColor, range: full)

        var inFence = false
        var codeRanges: [NSRange] = []
        text.enumerateSubstrings(
            in: full,
            options: [.byLines, .substringNotRequired]
        ) { _, lineRange, _, _ in
            let line = text.substring(with: lineRange)
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~") {
                storage.addAttributes([
                    .font: UIFont.monospacedSystemFont(ofSize: 14, weight: .regular),
                    .foregroundColor: WriterTheme.mutedUI,
                    .backgroundColor: WriterTheme.cardUI,
                ], range: lineRange)
                codeRanges.append(lineRange)
                inFence.toggle()
                return
            }
            if inFence {
                storage.addAttributes([
                    .font: UIFont.monospacedSystemFont(ofSize: 14, weight: .regular),
                    .backgroundColor: WriterTheme.cardUI,
                ], range: lineRange)
                codeRanges.append(lineRange)
                return
            }

            if let match = line.range(of: #"^#{1,6}\s"#, options: .regularExpression) {
                let level = line[match].trimmingCharacters(in: .whitespaces).count
                let markerRange = lineRange.offset(NSRange(match, in: line))
                storage.addAttributes([
                    .font: headingFont(level),
                    .foregroundColor: WriterTheme.foregroundUI,
                ], range: lineRange)
                storage.addAttribute(
                    .foregroundColor, value: WriterTheme.mutedUI, range: markerRange)
                return
            }

            if isRule(trimmed) {
                storage.addAttribute(
                    .foregroundColor, value: WriterTheme.mutedUI, range: lineRange)
                return
            }

            if trimmed.hasPrefix(">") {
                if let m = line.range(of: #"^\s*>+\s?"#, options: .regularExpression) {
                    storage.addAttribute(
                        .foregroundColor, value: WriterTheme.accentUI,
                        range: lineRange.offset(NSRange(m, in: line)))
                }
                storage.addAttribute(
                    .foregroundColor, value: WriterTheme.mutedUI,
                    range: NSRange(
                        location: lineRange.location + markerWidth(line),
                        length: max(0, lineRange.length - markerWidth(line))))
                return
            }

            // List markers: "- ", "1. ", "- [ ] "
            if let m = line.range(
                of: #"^\s*(?:[-*+]|\d+[.)])(?:\s+\[[ xX]\])?\s"#,
                options: .regularExpression) {
                storage.addAttribute(
                    .foregroundColor, value: WriterTheme.accentUI,
                    range: lineRange.offset(NSRange(m, in: line)))
            }
        }

        // Inline styles — skipped inside fenced code ranges.
        applyInline(storage, text: text, full: full, excluding: codeRanges)
        storage.endEditing()
    }

    private static func markerWidth(_ line: String) -> Int {
        guard let m = line.range(of: #"^\s*>+\s?"#, options: .regularExpression)
        else { return 0 }
        return NSRange(m, in: line).length
    }

    private static func isRule(_ trimmed: String) -> Bool {
        let compact = trimmed.replacingOccurrences(of: " ", with: "")
        guard compact.count >= 3, let c = compact.first else { return false }
        guard c == "-" || c == "*" || c == "_" else { return false }
        return compact.allSatisfy { $0 == c }
    }

    private static func applyInline(
        _ storage: NSTextStorage, text: NSString, full: NSRange,
        excluding codeRanges: [NSRange]
    ) {
        func excluded(_ range: NSRange) -> Bool {
            codeRanges.contains { NSIntersectionRange($0, range).length > 0 }
        }
        let muted = WriterTheme.mutedUI
        let accent = WriterTheme.accentUI
        let mono = UIFont.monospacedSystemFont(ofSize: 14, weight: .regular)

        for match in boldRegex.matches(in: text as String, range: full)
        where !excluded(match.range) {
            stylePair(storage, match: match.range, markerLen: 2) { range in
                let font = storage.attribute(.font, at: range.location, effectiveRange: nil)
                    as? UIFont ?? baseFont
                storage.addAttribute(.font, value: font.withBold(), range: range)
            }
        }
        for match in italicRegex.matches(in: text as String, range: full)
        where !excluded(match.range) {
            stylePair(storage, match: match.range, markerLen: 1) { range in
                let font = storage.attribute(.font, at: range.location, effectiveRange: nil)
                    as? UIFont ?? baseFont
                storage.addAttribute(.font, value: font.withItalic(), range: range)
            }
        }
        for match in codeRegex.matches(in: text as String, range: full)
        where !excluded(match.range) {
            stylePair(storage, match: match.range, markerLen: 1) { range in
                storage.addAttributes([
                    .font: mono,
                    .backgroundColor: WriterTheme.cardUI,
                ], range: range)
            }
        }
        for match in strikeRegex.matches(in: text as String, range: full)
        where !excluded(match.range) {
            stylePair(storage, match: match.range, markerLen: 2) { range in
                storage.addAttribute(
                    .strikethroughStyle, value: NSUnderlineStyle.single.rawValue,
                    range: range)
            }
        }
        for match in linkRegex.matches(in: text as String, range: full)
        where !excluded(match.range) {
            let whole = match.range
            let inner = match.range(at: 1)
            let url = match.range(at: 2)
            storage.addAttributes([
                .foregroundColor: accent,
                .underlineStyle: NSUnderlineStyle.single.rawValue,
            ], range: inner)
            // Brackets, parens and the URL dim; link text keeps the accent.
            var dim = IndexSet()
            dim.insert(whole.location)
            dim.insert(integersIn: Range(uncheckedBounds: (
                NSMaxRange(inner), NSMaxRange(whole) - 1)))
            dim.insert(integersIn: Range(uncheckedBounds: (
                url.location, NSMaxRange(url))))
            for r in dim.rangeView {
                storage.addAttribute(
                    .foregroundColor, value: muted, range: NSRange(r))
            }
        }
    }

    /// Applies `style` to the interior of a match and dims the surrounding
    /// marker characters (e.g. the `**` around bold text).
    private static func stylePair(
        _ storage: NSTextStorage,
        match: NSRange,
        markerLen: Int,
        style: (NSRange) -> Void
    ) {
        guard match.length > markerLen * 2 else { return }
        let inner = NSRange(
            location: match.location + markerLen,
            length: match.length - markerLen * 2)
        style(inner)
        let head = NSRange(location: match.location, length: markerLen)
        let tail = NSRange(location: NSMaxRange(inner), length: markerLen)
        storage.addAttribute(.foregroundColor, value: WriterTheme.mutedUI, range: head)
        storage.addAttribute(.foregroundColor, value: WriterTheme.mutedUI, range: tail)
        storage.addAttribute(.font, value: baseFont, range: head)
        storage.addAttribute(.font, value: baseFont, range: tail)
    }
}

private extension NSRange {
    /// Shifts a line-local range into document coordinates.
    func offset(_ local: NSRange) -> NSRange {
        NSRange(location: location + local.location, length: local.length)
    }
}

private extension UIFont {
    func withBold() -> UIFont {
        guard !fontDescriptor.symbolicTraits.contains(.traitBold) else { return self }
        return UIFont(
            descriptor: fontDescriptor.withSymbolicTraits(
                fontDescriptor.symbolicTraits.union(.traitBold))!,
            size: pointSize)
    }

    func withItalic() -> UIFont {
        guard !fontDescriptor.symbolicTraits.contains(.traitItalic) else { return self }
        return UIFont(
            descriptor: fontDescriptor.withSymbolicTraits(
                fontDescriptor.symbolicTraits.union(.traitItalic))!,
            size: pointSize)
    }
}
