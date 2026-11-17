// Swiftboard web port: stand-in for Telegram module TelegramPresentationData (API surface the chat list uses, fake data).
import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
@_exported import TelegramUIPreferences

public struct PresentationChatBubbleCorners: Equatable, Hashable {
    public var mainRadius: CGFloat, auxiliaryRadius: CGFloat, mergeBubbleCorners: Bool, hasTails: Bool
    public init(mainRadius: CGFloat, auxiliaryRadius: CGFloat, mergeBubbleCorners: Bool, hasTails: Bool = true) {
        self.mainRadius = mainRadius; self.auxiliaryRadius = auxiliaryRadius; self.mergeBubbleCorners = mergeBubbleCorners; self.hasTails = hasTails
    }
}
