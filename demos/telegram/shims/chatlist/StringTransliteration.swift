// Swiftboard web port: Telegram's ObjC StringTransliteration (CFStringTransform for search tokens). The web build
// lowercases and folds diacritics with Foundation instead of ICU transliteration.
import Foundation
public func postboxTransformedString(_ string: NSString, _ transliterate: Bool, _ combined: Bool) -> NSString {
    (string as String).lowercased().folding(options: [.diacriticInsensitive], locale: nil) as NSString
}
