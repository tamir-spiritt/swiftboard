// Swiftboard web port: AccountContext. Upstream it is the app's service locator (account, engine, shared context,
// downloads, calls, ...). The web port declares the members the chat list reads; WebAccountContext implements them
// over the in-memory account. Value types the chat list uses (ChatListControllerLocation, ChatLocation,
// PremiumConfiguration, PeerNameColors) are compiled from upstream (AccountContext.closure.json).
import Foundation
import UIKit
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramUIPreferences
import TelegramPresentationData
import AnimationCache
import MultiAnimationRenderer

public protocol SharedAccountContext: AnyObject {
    var energyUsageSettings: EnergyUsageSettings { get }
    var immediateExperimentalUISettings: ExperimentalUISettings { get }
}
public protocol AccountContext: AnyObject {
    var sharedContext: SharedAccountContext { get }
    var account: Account { get }
    var engine: TelegramEngine { get }
    var currentContentSettings: Atomic<ContentSettings> { get }
    var animationCache: AnimationCache { get }
    var animationRenderer: MultiAnimationRenderer { get }
    var peerNameColors: PeerNameColors { get }
    var isPremium: Bool { get }
    var imageCache: AnyObject? { get }
    var currentAppConfiguration: Atomic<AppConfiguration> { get }
}

public final class WebSharedAccountContext: SharedAccountContext {
    public let energyUsageSettings: EnergyUsageSettings = .default
    public let immediateExperimentalUISettings: ExperimentalUISettings = .defaultSettings
    public init() {}
}
public final class WebAccountContext: AccountContext {
    public let sharedContext: SharedAccountContext
    public let account: Account
    public let engine: TelegramEngine
    public let currentContentSettings = Atomic<ContentSettings>(value: .default)
    public let animationCache: AnimationCache = WebEmptyAnimationCache()
    public let animationRenderer: MultiAnimationRenderer = WebEmptyMultiAnimationRenderer()
    public let peerNameColors: PeerNameColors = .defaultValue
    public let isPremium = false
    public let imageCache: AnyObject? = nil
    public let currentAppConfiguration = Atomic<AppConfiguration>(value: .defaultValue)
    public init(accountPeerId: PeerId, sharedContext: SharedAccountContext) {
        self.sharedContext = sharedContext
        self.account = Account(peerId: accountPeerId)
        self.engine = TelegramEngine(account: account)
    }
}
