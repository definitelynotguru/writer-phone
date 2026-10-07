import SwiftUI

/// Rendered read mode for a markdown note. Task checkboxes are tappable and
/// write back into the source, matching writer-computer's checkable lists.
struct MarkdownPreview: View {
    let text: String
    var onToggleTask: (Int) -> Void

    private var parsed: (blocks: [MarkdownBlock], sourceLines: [String]) {
        MarkdownParser.parse(text)
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 10) {
                ForEach(parsed.blocks) { block in
                    view(for: block)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 60)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func view(for block: MarkdownBlock) -> some View {
        switch block.kind {
        case let .heading(level, text):
            Text(MarkdownParser.inline(text))
                .font(headingFont(level))
                .fontWeight(.bold)
                .foregroundStyle(WriterTheme.foreground)
                .padding(.top, level <= 2 ? 14 : 8)
                .textSelection(.enabled)

        case let .paragraph(text):
            Text(MarkdownParser.inline(text))
                .font(.system(size: WriterTheme.editorFontSize))
                .lineSpacing(WriterTheme.editorLineSpacing)
                .foregroundStyle(WriterTheme.foreground)
                .textSelection(.enabled)

        case let .bulleted(text, indent):
            listRow(marker: "•", indent: indent) {
                Text(MarkdownParser.inline(text))
            }

        case let .numbered(index, text, indent):
            listRow(marker: "\(index).", indent: indent) {
                Text(MarkdownParser.inline(text))
            }

        case let .task(checked, text, indent):
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Image(systemName: checked ? "checkmark.square.fill" : "square")
                    .foregroundStyle(WriterTheme.accent)
                    .font(.system(size: 17))
                Text(MarkdownParser.inline(text))
                    .foregroundStyle(WriterTheme.foreground)
            }
            .padding(.leading, CGFloat(indent) * 16)
            .contentShape(Rectangle())
            .onTapGesture { onToggleTask(block.lineIndex) }
            .textSelection(.enabled)

        case let .quote(text):
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(WriterTheme.accent.opacity(0.6))
                    .frame(width: 3)
                Text(MarkdownParser.inline(text))
                    .foregroundStyle(WriterTheme.muted)
            }
            .padding(.leading, 4)
            .textSelection(.enabled)

        case let .code(_, code):
            ScrollView(.horizontal, showsIndicators: false) {
                Text(code)
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundStyle(WriterTheme.foreground)
                    .padding(12)
                    .textSelection(.enabled)
            }
            .background(WriterTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 8))

        case .thematicBreak:
            Divider().overlay(WriterTheme.border).padding(.vertical, 6)
        }
    }

    @ViewBuilder
    private func listRow<Content: View>(
        marker: String, indent: Int,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(marker)
                .foregroundStyle(WriterTheme.accent)
                .font(.system(size: WriterTheme.editorFontSize, weight: .semibold))
            content()
                .font(.system(size: WriterTheme.editorFontSize))
                .foregroundStyle(WriterTheme.foreground)
        }
        .padding(.leading, CGFloat(indent) * 16)
        .textSelection(.enabled)
    }

    private func headingFont(_ level: Int) -> Font {
        switch level {
        case 1: return .system(size: 30)
        case 2: return .system(size: 25)
        case 3: return .system(size: 21)
        case 4: return .system(size: 18)
        case 5: return .system(size: 17)
        default: return .system(size: 16)
        }
    }
}
