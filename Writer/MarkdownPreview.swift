import SwiftUI

/// Rendered read mode for a markdown note. Task checkboxes are tappable and
/// write back into the source, matching writer-computer's checkable lists.
struct MarkdownPreview: View {
    let text: String
    var onToggleTask: (Int) -> Void = { _ in }

    private var parsed: (blocks: [MarkdownBlock], sourceLines: [String]) {
        MarkdownParser.parse(text)
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 10) {
                ForEach(parsed.blocks) { block in
                    MarkdownBlockView(block: block, onToggleTask: onToggleTask)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 60)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
