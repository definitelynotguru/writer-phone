import SwiftUI

/// Built-in markdown guide — each syntax shown raw beside its live render.
/// The task example is wired to a real toggle so people can try it.
struct IntroductionView: View {
    @State private var taskDemo = "- [ ] Tap to check me off"

    private struct Example: Identifiable {
        let id = UUID()
        let syntax: String
        let caption: String
    }

    private struct ExampleSection: Identifiable {
        let id = UUID()
        let title: String
        let examples: [Example]
    }

    private var sections: [ExampleSection] {
        [
            ExampleSection(title: "Headings", examples: [
                Example(syntax: "# Big heading", caption: "Largest title"),
                Example(syntax: "## Medium heading", caption: "Section header"),
                Example(syntax: "### Small heading", caption: "Subsection"),
            ]),
            ExampleSection(title: "Emphasis", examples: [
                Example(syntax: "**Bold text**", caption: "Bold"),
                Example(syntax: "*Italic text*", caption: "Italic"),
                Example(syntax: "~~Crossed out~~", caption: "Strikethrough"),
                Example(syntax: "`inline code`", caption: "Monospaced code"),
            ]),
            ExampleSection(title: "Lists", examples: [
                Example(syntax: "- Bullet item", caption: "Bullet point"),
                Example(syntax: "1. Numbered item", caption: "Numbered list"),
            ]),
            ExampleSection(title: "Blocks", examples: [
                Example(syntax: "> A quote", caption: "Blockquote"),
                Example(syntax: "```\nlet x = 1\n```", caption: "Fenced code block"),
                Example(syntax: "---", caption: "Divider line"),
            ]),
            ExampleSection(title: "Links", examples: [
                Example(syntax: "[Link text](https://example.com)", caption: "Tappable link"),
            ]),
        ]
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 22) {
                    Text("Writer notes are plain text with a few symbols that become formatting. Type them anywhere in a note:")
                        .font(.subheadline)
                        .foregroundStyle(WriterTheme.muted)
                        .padding(.bottom, 4)

                    ForEach(sections) { section in
                        VStack(alignment: .leading, spacing: 10) {
                            Text(section.title.uppercased())
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(WriterTheme.accent)
                            ForEach(section.examples) { example in
                                exampleRow(example)
                                if example.id != section.examples.last?.id {
                                    Divider().overlay(WriterTheme.border)
                                }
                            }
                        }
                        if section.title == "Lists" {
                            tasksRow
                        }
                    }

                    importSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 60)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(WriterTheme.background.ignoresSafeArea())
            .navigationTitle("Introduction")
        }
    }

    /// How to bring in notes from other apps — no syntax, so plain rows.
    private var importSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("IMPORT")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(WriterTheme.accent)
            VStack(alignment: .leading, spacing: 8) {
                Label("Share a note in Apple Notes or Journal → choose Writer — it lands as a note.", systemImage: "square.and.arrow.up")
                Label("Tap the import button on the Notes tab to pick .md/.txt files.", systemImage: "square.and.arrow.down")
                Label("In Files, tap a file → Copy to Writer.", systemImage: "folder")
            }
            .font(.subheadline)
            .foregroundStyle(WriterTheme.muted)
        }
    }

    private func exampleRow(_ example: Example) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(example.syntax)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(WriterTheme.accent)
                Spacer()
                Text(example.caption)
                    .font(.caption)
                    .foregroundStyle(WriterTheme.muted)
            }
            ForEach(MarkdownParser.parse(example.syntax).blocks) { block in
                MarkdownBlockView(block: block)
            }
        }
    }

    /// Live task demo — toggling actually rewrites the demo line.
    private var tasksRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("TASKS")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(WriterTheme.accent)
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(taskDemo)
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundStyle(WriterTheme.accent)
                    Spacer()
                    Text("Checkbox — tap it!")
                        .font(.caption)
                        .foregroundStyle(WriterTheme.muted)
                }
                ForEach(MarkdownParser.parse(taskDemo).blocks) { block in
                    MarkdownBlockView(block: block) { lineIndex in
                        let (_, lines) = MarkdownParser.parse(taskDemo)
                        taskDemo = MarkdownParser.toggledTaskLine(lines, at: lineIndex)
                    }
                }
            }
        }
    }
}
