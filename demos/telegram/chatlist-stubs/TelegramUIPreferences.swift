// Swiftboard web port: stand-in for Telegram module TelegramUIPreferences (API surface the chat list uses, fake data).
import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
@_exported import TelegramCore

public enum PresentationBuiltinThemeReference: Int32 {
    case dayClassic = 0, night = 1, day = 2, nightAccent = 3, neutral = 4, neutralNight = 5
    public init(baseTheme: PresentationBuiltinThemeName) {
        switch baseTheme { case .classic: self = .dayClassic; case .day: self = .day; case .night: self = .night; case .tinted: self = .nightAccent }
    }
}
public enum PresentationBuiltinThemeName: Int32 { case classic, day, night, tinted }
extension PresentationBuiltinThemeReference {
    public var baseTheme: PresentationBuiltinThemeName {
        switch self { case .dayClassic: return .classic; case .day, .neutral: return .day; case .night, .neutralNight: return .night; case .nightAccent: return .tinted }
    }
}
public enum PresentationThemeReference: Equatable {
    case builtin(PresentationBuiltinThemeReference)
    case cloud(PresentationCloudTheme)
    public var index: Int64 { if case let .builtin(r) = self { return Int64(r.rawValue) }; return 0 }
    public var generalThemeReference: PresentationThemeReference { self }
}
public enum PresentationFontSize: Int32, CaseIterable {
    case extraSmall = 0, small = 1, medium = 2, regular = 3, large = 4, extraLarge = 5, extraLargeX2 = 6
    public var baseDisplaySize: CGFloat {
        switch self { case .extraSmall: return 14; case .small: return 15; case .medium: return 16; case .regular: return 17; case .large: return 19; case .extraLarge: return 23; case .extraLargeX2: return 26 }
    }
}

public struct TelegramTheme: Equatable { public let id: Int64; public let title: String; public init(id: Int64, title: String) { self.id = id; self.title = title } }
public struct PresentationCloudTheme: Equatable { public let theme: TelegramTheme; public let resolvedWallpaper: TelegramWallpaper?; public init(theme: TelegramTheme, resolvedWallpaper: TelegramWallpaper?) { self.theme = theme; self.resolvedWallpaper = resolvedWallpaper } }
