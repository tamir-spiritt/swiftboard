// Swiftboard web port: EmojiTextAttachmentView's InlineStickerItemLayer (custom emoji: animated stickers decoded
// through rlottie/WebM). Not ported: the layer keeps the upstream API and shows nothing; the text around it renders.
import Foundation
import UIKit
import SwiftSignalKit
import Display
import ComponentFlow
import Postbox
import TelegramCore
import TelegramUIPreferences
import AccountContext
import AnimationCache
import MultiAnimationRenderer
import TextFormat

public final class InlineStickerItemLayer: MultiAnimationRenderTarget {
    public enum Context: Equatable {
        public final class Custom: Equatable {
            public let postbox: Postbox
            public let energyUsageSettings: () -> EnergyUsageSettings
            public let resolveInlineStickers: ([Int64]) -> Signal<[Int64: TelegramMediaFile], NoError>
            public init(postbox: Postbox, energyUsageSettings: @escaping () -> EnergyUsageSettings, resolveInlineStickers: @escaping ([Int64]) -> Signal<[Int64: TelegramMediaFile], NoError>) {
                self.postbox = postbox; self.energyUsageSettings = energyUsageSettings; self.resolveInlineStickers = resolveInlineStickers
            }
            public static func == (lhs: Custom, rhs: Custom) -> Bool { lhs === rhs }
        }
        case account(AccountContext)
        case custom(Custom)
        public static func == (lhs: Context, rhs: Context) -> Bool {
            switch (lhs, rhs) {
            case let (.account(a), .account(b)): return a === b
            case let (.custom(a), .custom(b)): return a == b
            default: return false
            }
        }
    }
    public struct Key: Hashable {
        public var id: Int64
        public var index: Int
        public init(id: Int64, index: Int) { self.id = id; self.index = index }
    }
    public static let queue = Queue()
    public var contentTintColor: UIColor?
    public var dynamicColor: UIColor?
    public var isUnique: Bool = false
    public var isVisibleForAnimations: Bool = false
    public var enableAnimation: Bool = true
    public convenience init(context: AccountContext, userLocation: MediaResourceUserLocation, attemptSynchronousLoad: Bool, emoji: ChatTextInputTextCustomEmojiAttribute, file: TelegramMediaFile?, cache: AnimationCache, renderer: MultiAnimationRenderer, unique: Bool = false, placeholderColor: UIColor, pointSize: CGSize, dynamicColor: UIColor? = nil, loopCount: Int? = nil) {
        self.init(context: .account(context), userLocation: userLocation, attemptSynchronousLoad: attemptSynchronousLoad, emoji: emoji, file: file, cache: cache, renderer: renderer, unique: unique, placeholderColor: placeholderColor, pointSize: pointSize, dynamicColor: dynamicColor, loopCount: loopCount)
    }
    public init(context: InlineStickerItemLayer.Context, userLocation: MediaResourceUserLocation, attemptSynchronousLoad: Bool, emoji: ChatTextInputTextCustomEmojiAttribute, file: TelegramMediaFile?, cache: AnimationCache, renderer: MultiAnimationRenderer, unique: Bool = false, placeholderColor: UIColor, pointSize: CGSize, dynamicColor: UIColor? = nil, loopCount: Int? = nil) {
        self.dynamicColor = dynamicColor
        super.init()
    }
    public override init(layer: Any) { super.init(layer: layer) }
    public required init?(coder: NSCoder) { nil }
    public func updateTintColor(contentTintColor: UIColor?, dynamicColor: UIColor?, transition: ComponentTransition) {
        self.contentTintColor = contentTintColor; self.dynamicColor = dynamicColor
    }
    public func playOnce() {}
    public func reloadAnimation() {}
}

/// Forum topic icon (upstream EmojiTextAttachmentView.generateTopicIcon): not ported yet, no icon.
public func generateTopicIcon(title: String, backgroundColors: [UIColor], strokeColors: [UIColor], size: CGSize) -> UIImage? { nil }
