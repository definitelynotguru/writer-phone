import XCTest
@testable import Writer

final class MarkdownParserTests: XCTestCase {
    func testHeadings() {
        let (blocks, _) = MarkdownParser.parse("# Title\n## Sub\nBody")
        XCTAssertEqual(blocks.count, 3)
        XCTAssertEqual(blocks[0].kind, .heading(level: 1, text: "Title"))
        XCTAssertEqual(blocks[1].kind, .heading(level: 2, text: "Sub"))
        XCTAssertEqual(blocks[2].kind, .paragraph(text: "Body"))
    }

    func testHeadingRequiresSpace() {
        let (blocks, _) = MarkdownParser.parse("#notaheading")
        XCTAssertEqual(blocks, [MarkdownBlock(lineIndex: 0, kind: .paragraph(text: "#notaheading"))])
    }

    func testTaskItems() {
        let (blocks, _) = MarkdownParser.parse("- [ ] todo\n- [x] done\n- plain")
        XCTAssertEqual(blocks[0].kind, .task(checked: false, text: "todo", indent: 0))
        XCTAssertEqual(blocks[1].kind, .task(checked: true, text: "done", indent: 0))
        XCTAssertEqual(blocks[2].kind, .bulleted(text: "plain", indent: 0))
    }

    func testNumberedList() {
        let (blocks, _) = MarkdownParser.parse("1. first\n2. second")
        XCTAssertEqual(blocks[0].kind, .numbered(index: 1, text: "first", indent: 0))
        XCTAssertEqual(blocks[1].kind, .numbered(index: 2, text: "second", indent: 0))
    }

    func testFencedCodeSwallowsMarkdown() {
        let (blocks, _) = MarkdownParser.parse("```\n# not a heading\n- not a list\n```")
        XCTAssertEqual(blocks.count, 1)
        XCTAssertEqual(blocks[0].kind, .code(language: nil, text: "# not a heading\n- not a list"))
    }

    func testCodeLanguage() {
        let (blocks, _) = MarkdownParser.parse("```swift\nlet x = 1\n```")
        XCTAssertEqual(blocks[0].kind, .code(language: "swift", text: "let x = 1"))
    }

    func testParagraphJoinsLinesAndSkipsBlanks() {
        let (blocks, _) = MarkdownParser.parse("line one\nline two\n\nnext para")
        XCTAssertEqual(blocks.count, 2)
        XCTAssertEqual(blocks[0].kind, .paragraph(text: "line one line two"))
        XCTAssertEqual(blocks[1].kind, .paragraph(text: "next para"))
    }

    func testQuoteAndRule() {
        let (blocks, _) = MarkdownParser.parse("> quoted\n---")
        XCTAssertEqual(blocks[0].kind, .quote(text: "quoted"))
        XCTAssertEqual(blocks[1].kind, .thematicBreak)
    }

    func testToggleTask() {
        let source = "- [ ] a\n- [x] b"
        let (_, lines) = MarkdownParser.parse(source)
        let toggled = MarkdownParser.toggledTaskLine(lines, at: 0)
        XCTAssertEqual(toggled.components(separatedBy: "\n")[0], "- [x] a")
        let toggled2 = MarkdownParser.toggledTaskLine(lines, at: 1)
        XCTAssertEqual(toggled2.components(separatedBy: "\n")[1], "- [ ] b")
    }

    func testInlineParsing() {
        let str = MarkdownParser.inline("hello **bold** `code`")
        XCTAssertTrue(String(describing: str).contains("bold"))
    }
}

final class NoteStoreTests: XCTestCase {
    func testPreviewStripsMarkers() {
        let preview = NoteStore.makePreview(of: "# Title\n> quote\n- item\n- [ ] task")
        XCTAssertEqual(preview, "Title quote item task")
    }

    func testPreviewCapsLength() {
        let long = String(repeating: "word ", count: 100)
        XCTAssertLessThanOrEqual(NoteStore.makePreview(of: long).count, 140)
    }

    func testImportFilesDedupesNames() throws {
        let store = NoteStore()
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let src = tmp.appendingPathComponent("Daily Notes.md")
        try "imported body".write(to: src, atomically: true, encoding: .utf8)

        // Seed an existing note with the same title so the import must rename.
        let existing = store.directory.appendingPathComponent("Daily Notes.md")
        try? "original".write(to: existing, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: store.directory.appendingPathComponent("Daily Notes 2.md")) }

        XCTAssertEqual(store.importFiles([src]), 1)
        XCTAssertTrue(store.notes.contains { $0.title == "Daily Notes 2" })
    }

    func testImportFilesSkipsUnreadableAndEmpty() throws {
        let store = NoteStore()
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let empty = tmp.appendingPathComponent("Empty.md")
        try "   \n".write(to: empty, atomically: true, encoding: .utf8)
        let missing = tmp.appendingPathComponent("Nope.md")

        XCTAssertEqual(store.importFiles([empty, missing]), 0)
    }
}
