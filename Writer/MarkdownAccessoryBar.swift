import UIKit

/// UIKit input accessory with markdown formatting buttons — a UITextView's
/// own accessory, since SwiftUI's .keyboard toolbar doesn't attach to a
/// representable text view.
final class MarkdownAccessoryBar: UIView {
    private let formatter: EditorFormatter

    init(formatter: EditorFormatter) {
        self.formatter = formatter
        super.init(frame: CGRect(x: 0, y: 0, width: 0, height: 44))
        autoresizingMask = .flexibleHeight
        backgroundColor = WriterTheme.backgroundUI.withAlphaComponent(0.96)

        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 4
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        stack.addArrangedSubview(button("number") { [weak self] in
            self?.formatter.heading()
        })
        stack.addArrangedSubview(button("bold") { [weak self] in
            self?.formatter.wrap("**")
        })
        stack.addArrangedSubview(button("italic") { [weak self] in
            self?.formatter.wrap("*")
        })
        stack.addArrangedSubview(button("chevron.left.forwardslash.chevron.right") { [weak self] in
            self?.formatter.wrap("`")
        })
        stack.addArrangedSubview(button("list.bullet") { [weak self] in
            self?.formatter.bullet()
        })
        stack.addArrangedSubview(button("checklist") { [weak self] in
            self?.formatter.task()
        })
        stack.addArrangedSubview(button("text.quote") { [weak self] in
            self?.formatter.quote()
        })

        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        stack.addArrangedSubview(spacer)

        stack.addArrangedSubview(button("keyboard.chevron.compact.down") { [weak self] in
            self?.formatter.textView?.resignFirstResponder()
        })
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    private func button(_ systemImage: String, action: @escaping () -> Void) -> UIButton {
        let b = UIButton(type: .system, primaryAction: UIAction { _ in action() })
        b.setImage(UIImage(systemName: systemImage), for: .normal)
        b.tintColor = WriterTheme.foregroundUI.withAlphaComponent(0.85)
        b.widthAnchor.constraint(equalToConstant: 38).isActive = true
        b.heightAnchor.constraint(equalToConstant: 38).isActive = true
        return b
    }
}
