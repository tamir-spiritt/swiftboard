// Swiftboard web port: shim for what the compiled ChatListUI subset (ChatListItem and its nodes) needs from the rest
// of ChatListUI and app code the port does not build.
import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import AccountContext
import PersistentStringHash // upstream reaches String.persistentHashValue transitively
import ComponentDisplayAdapters // upstream reaches ComponentTransition(ContainedViewLayoutTransition) transitively
import AnimationCache
import MultiAnimationRenderer

/// Upstream ChatListNode.swift: the list controller node (history views, transitions, search). Not compiled; the web
/// port keeps the one nested type ChatListItem refers to.
public final class ChatListNode {
    public enum OpenStoriesSubject {
        case peer(EnginePeer.Id)
        case archive
    }
}

/// Upstream ChatListNode.swift: ChatListNodeInteraction (40 callbacks into the controller). The web port keeps the
/// members ChatListItem uses, with the upstream types; callbacks the host does not provide are no-ops.
public final class ChatListNodeInteraction {
    let peerSelected: (EnginePeer, EnginePeer?, Int64?, ChatListNodeEntryPromoInfo?, Bool) -> Void
    let togglePeerSelected: (EnginePeer, Int64?) -> Void = { _, _ in }
    let messageSelected: (EnginePeer, Int64?, EngineMessage, ChatListNodeEntryPromoInfo?) -> Void
    let groupSelected: (EngineChatList.Group) -> Void = { _ in }
    let setPeerIdWithRevealedOptions: (EnginePeer.Id?, EnginePeer.Id?) -> Void
    let setItemPinned: (EngineChatList.PinnedItem.Id, Bool) -> Void = { _, _ in }
    let setPeerMuted: (EnginePeer.Id, Bool) -> Void = { _, _ in }
    let setPeerThreadMuted: (EnginePeer.Id, Int64?, Bool) -> Void = { _, _, _ in }
    let deletePeer: (EnginePeer.Id, Bool) -> Void = { _, _ in }
    let deletePeerThread: (EnginePeer.Id, Int64) -> Void = { _, _ in }
    let setPeerThreadStopped: (EnginePeer.Id, Int64, Bool) -> Void = { _, _, _ in }
    let setPeerThreadPinned: (EnginePeer.Id, Int64, Bool) -> Void = { _, _, _ in }
    let setPeerThreadHidden: (EnginePeer.Id, Int64, Bool) -> Void = { _, _, _ in }
    let updatePeerGrouping: (EnginePeer.Id, Bool) -> Void = { _, _ in }
    let togglePeerMarkedUnread: (EnginePeer.Id, Bool) -> Void = { _, _ in }
    let toggleArchivedFolderHiddenByDefault: () -> Void = {}
    let toggleThreadsSelection: ([Int64], Bool) -> Void = { _, _ in }
    let hidePsa: (EnginePeer.Id) -> Void = { _ in }
    let activateChatPreview: ((ChatListItem, Int64?, ASDisplayNode, ContextGesture?, CGPoint?) -> Void)? = nil
    let openForumThread: (EnginePeer.Id, Int64) -> Void = { _, _ in }
    let openStories: (ChatListNode.OpenStoriesSubject, ASDisplayNode?) -> Void = { _, _ in }
    let openCommunity: (EnginePeer.Id) -> Void = { _ in }
    let ungroupCommunity: (EnginePeer.Id) -> Void = { _ in }
    let editPeer: (ChatListItem) -> Void = { _ in }
    let openWebApp: (TelegramUser) -> Void = { _ in }
    public var searchTextHighightState: String?
    var highlightedChatLocation: ChatListHighlightedLocation?
    var isSearchMode: Bool = false
    var isInlineMode: Bool = false
    var isSideListMode: Bool = false
    var openSideListAllThreads: (() -> Void)?
    var inlineNavigationLocation: ChatListHighlightedLocation?
    let animationCache: AnimationCache
    let animationRenderer: MultiAnimationRenderer

    public init(animationCache: AnimationCache, animationRenderer: MultiAnimationRenderer,
                peerSelected: @escaping (EnginePeer, EnginePeer?, Int64?, ChatListNodeEntryPromoInfo?, Bool) -> Void,
                messageSelected: @escaping (EnginePeer, Int64?, EngineMessage, ChatListNodeEntryPromoInfo?) -> Void = { _, _, _, _ in },
                setPeerIdWithRevealedOptions: @escaping (EnginePeer.Id?, EnginePeer.Id?) -> Void = { _, _ in }) {
        self.animationCache = animationCache
        self.animationRenderer = animationRenderer
        self.peerSelected = peerSelected
        self.messageSelected = messageSelected
        self.setPeerIdWithRevealedOptions = setPeerIdWithRevealedOptions
    }
}
