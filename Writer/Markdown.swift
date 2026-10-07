import Foundation

/// Line-oriented block parser covering the markdown subset Writer renders:
/// ATX headings, paragraphs, bulleted/numbered/task lists, blockquotes,
/// fenced code, and thematic breaks. Inline syntax is left to Foundation's
/// `AttributedString(markdown:)` inline parser.
struct MarkdownBlock: Identifiable, Equatable {
    enum Kind: Equatable {
        case heading(level: Int, text: String)
        case paragraph(text: String)
        case bulleted(text: String, indent: Int)
        case numbered(index: Int, text: String, indent: Int)
        case task(checked: Bool, text: String, indent: Int)
        case quote(text: String)
        case code(language: String?, text: String)
        case thematicBreak
    }

    /// Index of the source line this block starts on; doubles as `id`.
    let lineIndex: Int
    let kind: Kind

    var id: Int { lineIndex }
}

enum MarkdownParser {
    /// Splits source into display blocks. `sourceLines` echoes the raw lines
    /// so callers can map a block's `lineIndex` back to source for editing.
    static func parse(_ source: String) -> (blocks: [MarkdownBlock], sourceLines: [String]) {
        let lines = source.components(separatedBy: "\n")
        var blocks: [MarkdownBlock] = []
        var paragraph: [String] = []
        var paragraphStart = 0
        var inCode = false
        var codeStart = 0
        var codeFence = ""
        var codeLang: String?
        var codeLines: [String] = []

        func flushParagraph() {
            guard !paragraph.isEmpty else { return }
            blocks.append(MarkdownBlock(
                lineIndex: paragraphStart,
                kind: .paragraph(text: paragraph.joined(separator: " "))
            ))
            paragraph = []
        }

        for (i, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if inCode {
                if trimmed.hasPrefix(codeFence) {
                    blocks.append(MarkdownBlock(
                        lineIndex: codeStart,
                        kind: .code(language: codeLang, text: codeLines.joined(separator: "\n"))
                    ))
                    inCode = false
                    codeLines = []
                    codeLang = nil
                } else {
                    codeLines.append(line)
                }
                continue
            }

            if trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~") {
                flushParagraph()
                inCode = true
                codeStart = i
                codeFence = String(trimmed.prefix(3))
                codeLang = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                if codeLang?.isEmpty == true { codeLang = nil }
                continue
            }

            if trimmed.isEmpty {
                flushParagraph()
                continue
            }

            if let heading = parseHeading(trimmed) {
                flushParagraph()
                blocks.append(MarkdownBlock(lineIndex: i, kind: heading))
                continue
            }

            if isThematicBreak(trimmed) {
                flushParagraph()
                blocks.append(MarkdownBlock(lineIndex: i, kind: .thematicBreak))
                continue
            }

            if trimmed.hasPrefix(">") {
                flushParagraph()
                let text = String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces)
                blocks.append(MarkdownBlock(lineIndex: i, kind: .quote(text: text)))
                continue
            }

            if let item = parseListItem(line) {
                flushParagraph()
                blocks.append(MarkdownBlock(lineIndex: i, kind: item))
                continue
            }

            if paragraph.isEmpty { paragraphStart = i }
            paragraph.append(trimmed)
        }

        if inCode {
            blocks.append(MarkdownBlock(
                lineIndex: codeStart,
                kind: .code(language: codeLang, text: codeLines.joined(separator: "\n"))
            ))
        }
        flushParagraph()
        return (blocks, lines)
    }

    /// Rewrites a single source line (used by tappable task checkboxes) and
    /// returns the full re-joined document.
    static func replacingLine(_ sourceLines: [String], at index: Int, with newLine: String) -> String {
        var lines = sourceLines
        guard lines.indices.contains(index) else { return lines.joined(separator: "\n") }
        lines[index] = newLine
        return lines.joined(separator: "\n")
    }

    static func toggledTaskLine(_ sourceLines: [String], at index: Int) -> String {
        guard sourceLines.indices.contains(index) else { return sourceLines.joined(separator: "\n") }
        let line = sourceLines[index]
        var out = line
        if let range = line.range(of: "[ ]") {
            out.replaceSubrange(range, with: "[x]")
        } else if let range = line.range(of: "[x]") ?? line.range(of: "[X]") {
            out.replaceSubrange(range, with: "[ ]")
        }
        return replacingLine(sourceLines, at: index, with: out)
    }

    private static func parseHeading(_ trimmed: String) -> MarkdownBlock.Kind? {
        var level = 0
        for c in trimmed {
            if c == "#" { level += 1 } else { break }
        }
        guard level >= 1, level <= 6 else { return nil }
        let rest = trimmed.dropFirst(level)
        guard rest.first == " " || rest.isEmpty else { return nil }
        return .heading(level: level, text: String(rest).trimmingCharacters(in: .whitespaces))
    }

    private static func isThematicBreak(_ trimmed: String) -> Bool {
        guard trimmed.count >= 3 else { return false }
        let compact = trimmed.replacingOccurrences(of: " ", with: "")
        guard compact.count >= 3, let c = compact.first else { return false }
        guard c == "-" || c == "*" || c == "_" else { return false }
        return compact.allSatisfy { $0 == c }
    }

    private static func parseListItem(_ line: String) -> MarkdownBlock.Kind? {
        let indent = line.prefix(while: { $0 == " " }).count / 2
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        // Unordered / task items: "- x", "* x", "+ x", "- [ ] x"
        if trimmed.count >= 2,
           let marker = trimmed.first,
           "-*+".contains(marker),
           trimmed.dropFirst().first == " " {
            let rest = trimmed.dropFirst(2)
            if rest.hasPrefix("[ ] ") || rest.hasPrefix("[x] ") || rest.hasPrefix("[X] ") {
                return .task(
                    checked: !rest.hasPrefix("[ ]"),
                    text: String(rest.dropFirst(4)),
                    indent: indent
                )
            }
            return .bulleted(text: String(rest), indent: indent)
        }

        // Numbered: "1. x" / "2) y"
        var digits = ""
        var j = trimmed.startIndex
        while j < trimmed.endIndex, trimmed[j].isNumber {
            digits.append(trimmed[j])
            j = trimmed.index(after: j)
        }
        if !digits.isEmpty,
           j < trimmed.endIndex,
           trimmed[j] == "." || trimmed[j] == ")" {
            let after = trimmed.index(after: j)
            if after < trimmed.endIndex, trimmed[after] == " " {
                return .numbered(
                    index: Int(digits) ?? 0,
                    text: String(trimmed[trimmed.index(after: after)...]),
                    indent: indent
                )
            }
        }
        return nil
    }

    /// Inline markdown (bold, italic, code, links, strikethrough) via
    /// Foundation's CommonMark inline parser. Falls back to literal text.
    static func inline(_ text: String) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .inlineOnlyPreservingWhitespace
        )
        if let parsed = try? AttributedString(markdown: text, options: options) {
            return parsed
        }
        return AttributedString(text)
    }
}
