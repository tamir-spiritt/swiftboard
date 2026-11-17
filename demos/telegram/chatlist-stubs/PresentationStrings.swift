// Swiftboard web port: runtime for the generated PresentationStrings (tools/gen-strings.py). Upstream generates an
// ObjC module; this keeps its Swift API (_PresentationStrings, _FormattedString) with English strings.
import Foundation

public final class _FormattedStringRange {
    public let index: Int
    public let range: NSRange
    public init(index: Int, range: NSRange) { self.index = index; self.range = range }
}
public final class _FormattedString {
    public let string: String
    public let ranges: [_FormattedStringRange]
    public init(string: String, ranges: [_FormattedStringRange]) { self.string = string; self.ranges = ranges }
}
public final class _PresentationStringsComponent {
    public let languageCode: String
    public let localizedName: String
    public let pluralizationRulesCode: String?
    public let dict: [String: String]
    public init(languageCode: String, localizedName: String, pluralizationRulesCode: String?, dict: [String: String]) {
        self.languageCode = languageCode; self.localizedName = localizedName; self.pluralizationRulesCode = pluralizationRulesCode; self.dict = dict
    }
}
public final class _PresentationStrings: Equatable {
    public let lc: UInt32 = 0x656e
    public let primaryComponent: _PresentationStringsComponent
    public let secondaryComponent: _PresentationStringsComponent?
    public let baseLanguageCode: String
    public let groupingSeparator: String
    public init(primaryComponent: _PresentationStringsComponent, secondaryComponent: _PresentationStringsComponent?, groupingSeparator: String?) {
        self.primaryComponent = primaryComponent; self.secondaryComponent = secondaryComponent
        baseLanguageCode = secondaryComponent?.languageCode ?? primaryComponent.languageCode
        self.groupingSeparator = groupingSeparator ?? ","
    }
    public convenience init() {
        self.init(primaryComponent: _PresentationStringsComponent(languageCode: "en", localizedName: "English", pluralizationRulesCode: nil, dict: [:]), secondaryComponent: nil, groupingSeparator: ",")
    }
    public static func == (a: _PresentationStrings, b: _PresentationStrings) -> Bool { a === b }

    /// English plural rule: 1 -> "1", else "any"/"many"/"other".
    func _plural(_ value: Int32, _ forms: [String: String]) -> String {
        let key = value == 1 ? "1" : (value == 0 ? "0" : "any")
        let f = forms[key] ?? forms[value == 1 ? "1" : "many"] ?? forms["any"] ?? forms["many"] ?? forms["other"] ?? forms.values.first ?? ""
        return _format(f, ["\(value)"]).string
    }
    func _format(_ format: String, _ args: [String]) -> _FormattedString {
        var out = ""
        var ranges: [_FormattedStringRange] = []
        var implicit = 0
        var i = format.startIndex
        while i < format.endIndex {
            let c = format[i]
            if c == "%" {
                var j = format.index(after: i)
                if j < format.endIndex && format[j] == "%" { out += "%"; i = format.index(after: j); continue }
                var digits = ""
                while j < format.endIndex, format[j].isNumber { digits.append(format[j]); j = format.index(after: j) }
                var index = implicit
                if j < format.endIndex, format[j] == "$", let n = Int(digits) { index = n - 1; j = format.index(after: j) } else { implicit += 1 }
                if j < format.endIndex, format[j] == "@" || format[j] == "d" {
                    let a = index < args.count ? args[index] : ""
                    let loc = (out as NSString).length
                    out += a
                    ranges.append(_FormattedStringRange(index: index, range: NSRange(location: loc, length: (a as NSString).length)))
                    i = format.index(after: j)
                    continue
                }
            }
            out.append(c)
            i = format.index(after: i)
        }
        return _FormattedString(string: out, ranges: ranges)
    }
}
public typealias PresentationStrings = _PresentationStrings
public typealias PresentationStringsComponent = _PresentationStringsComponent
