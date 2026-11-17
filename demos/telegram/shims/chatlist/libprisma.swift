// Swiftboard web port: libprisma (C++ code-block syntax highlighter behind an ObjC Syntaxer). Not ported:
// Syntaxer() fails, so code blocks render unhighlighted.
import Foundation
import UIKit
public final class SyntaxterTheme: NSObject {
    public var dark: Bool, textColor: UIColor, textFont: UIFont, italicFont: UIFont, mediumFont: UIFont
    public init!(dark: Bool, textColor: UIColor, textFont: UIFont, italicFont: UIFont, mediumFont: UIFont) {
        self.dark = dark; self.textColor = textColor; self.textFont = textFont; self.italicFont = italicFont; self.mediumFont = mediumFont
    }
}
public final class Syntaxer {
    public init?() { return nil }
    public func syntax(_ code: String, language: String, theme: SyntaxterTheme) -> NSAttributedString? { nil }
}
