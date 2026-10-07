import SwiftUI
import UIKit

/// Design tokens ported from writer-computer's App.css:
/// accent #ff6a00, bg #111111, fg #fcfcfc (dark); inverted for light.
enum WriterTheme {
    static let accent = Color(red: 1.0, green: 106.0 / 255.0, blue: 0.0)
    static let accentUI = UIColor(red: 1.0, green: 106.0 / 255.0, blue: 0.0, alpha: 1.0)

    static let backgroundUI = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0x11 / 255.0, green: 0x11 / 255.0, blue: 0x11 / 255.0, alpha: 1)
            : UIColor(red: 0xFC / 255.0, green: 0xFC / 255.0, blue: 0xFC / 255.0, alpha: 1)
    }
    static var background: Color { Color(uiColor: backgroundUI) }

    static let foregroundUI = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0xFC / 255.0, green: 0xFC / 255.0, blue: 0xFC / 255.0, alpha: 1)
            : UIColor(red: 0x16 / 255.0, green: 0x16 / 255.0, blue: 0x16 / 255.0, alpha: 1)
    }
    static var foreground: Color { Color(uiColor: foregroundUI) }

    /// fg at 54% — --text-muted
    static var muted: Color { foreground.opacity(0.54) }
    static let mutedUI = foregroundUI.withAlphaComponent(0.54)

    /// fg at 16% — --surface-card / --code-bg
    static var card: Color { foreground.opacity(0.16) }
    static let cardUI = foregroundUI.withAlphaComponent(0.16)

    /// fg at 24% — --border-color
    static let borderUI = foregroundUI.withAlphaComponent(0.24)
    static var border: Color { foreground.opacity(0.24) }

    static let editorFontSize: CGFloat = 16
    /// 16pt system ~19.1pt line height; desktop uses 1.875x line height —
    /// +8pt spacing lands at ~1.5x, airy but still phone-sized.
    static let editorLineSpacing: CGFloat = 8
}
