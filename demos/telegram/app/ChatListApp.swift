// Browser demo of Telegram's chat list with the real cell: ten sample chats rendered by ChatListUI's ChatListItem /
// ChatListItemNode inside Display's ListView. The data is built from the real engine types (TelegramUser,
// TelegramGroup, Postbox Message, EngineRenderedPeer, read states); only storage and network are absent.
import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import AccountContext
import ChatListUI

nonisolated(unsafe) var chatListRetain: [AnyObject] = []

private struct SampleChat {
    var name: String
    var isGroup = false
    var text: String
    var minutesAgo: Int
    var unread: Int32 = 0
    var muted = false
    var pinned = false
    var online = false
    var outgoing: Bool? = nil // nil: incoming; true: outgoing, read; false: outgoing, unread
}

private let samples: [SampleChat] = [
    SampleChat(name: "Saved Messages", text: "Swiftboard: Telegram's real ChatListItemNode on WebAssembly", minutesAgo: 3, pinned: true, outgoing: true),
    SampleChat(name: "Pavel Durov", text: "Ship it 🚀", minutesAgo: 15, unread: 2, pinned: true, online: true),
    SampleChat(name: "Design Team", isGroup: true, text: "The new chat list cells look right at every font size", minutesAgo: 47, unread: 14),
    SampleChat(name: "Alex Chen", text: "Running the Swift compiler output in a browser canvas is wild", minutesAgo: 64, online: true, outgoing: false),
    SampleChat(name: "Telegram Tips", text: "Swipe a chat left to archive it, right to mark it as read.", minutesAgo: 150, unread: 1, muted: true),
    SampleChat(name: "Family", isGroup: true, text: "Dinner at 7?", minutesAgo: 60 * 26, unread: 3, muted: true),
    SampleChat(name: "Nora Weiss", text: "See you there", minutesAgo: 60 * 50, outgoing: true),
    SampleChat(name: "Swift Developers", isGroup: true, text: "WASI reactor builds work with -mexec-model=reactor", minutesAgo: 60 * 75, unread: 128, muted: true),
    SampleChat(name: "Liam O'Brien", text: "Sounds good, talk tomorrow", minutesAgo: 60 * 100, online: true, outgoing: true),
    SampleChat(name: "Crypto Signals", isGroup: true, text: "Never share your recovery phrase", minutesAgo: 60 * 125, muted: true),
]

private func peerId(_ n: Int64, group: Bool = false) -> PeerId {
    PeerId(namespace: group ? Namespaces.Peer.CloudGroup : Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(n))
}

private func makePeer(_ chat: SampleChat, id: PeerId) -> Peer {
    if chat.isGroup {
        return TelegramGroup(id: id, title: chat.name, photo: [], participantCount: 12, role: .member, membership: .Member, flags: TelegramGroupFlags(), defaultBannedRights: nil, migrationReference: nil, creationDate: 0, version: 0)
    }
    let parts = chat.name.split(separator: " ", maxSplits: 1).map(String.init)
    return TelegramUser(id: id, accessHash: nil, firstName: parts.first, lastName: parts.count > 1 ? parts[1] : nil, username: nil, phone: nil, photo: [], botInfo: nil, restrictionInfo: nil, flags: UserInfoFlags(), emojiStatus: nil, usernames: [], storiesHidden: nil, nameColor: nil, backgroundEmojiId: nil, profileColor: nil, profileBackgroundEmojiId: nil, subscriberCount: nil, verificationIconFileId: nil)
}

@_cdecl("app_start")
public func app_start() {
    let screen = UIScreen.main.bounds
    let theme = makeDefaultDayPresentationTheme(serviceBackgroundColor: nil, day: false, preview: false)
    let strings = defaultPresentationStrings
    let accountPeerId = peerId(1)
    let me = TelegramUser(id: accountPeerId, accessHash: nil, firstName: "Me", lastName: nil, username: nil, phone: nil, photo: [], botInfo: nil, restrictionInfo: nil, flags: UserInfoFlags(), emojiStatus: nil, usernames: [], storiesHidden: nil, nameColor: nil, backgroundEmojiId: nil, profileColor: nil, profileBackgroundEmojiId: nil, subscriberCount: nil, verificationIconFileId: nil)
    let context = WebAccountContext(accountPeerId: accountPeerId, sharedContext: WebSharedAccountContext())
    let presentationData = ChatListPresentationData(theme: theme, fontSize: .regular, strings: strings, dateTimeFormat: PresentationDateTimeFormat(), nameSortOrder: .firstLast, nameDisplayOrder: .firstLast, disableAnimations: true)
    let interaction = ChatListNodeInteraction(animationCache: context.animationCache, animationRenderer: context.animationRenderer, peerSelected: { peer, _, _, _, _ in
        print("[swift] chat selected: \(peer.debugDisplayTitle)")
    }, messageSelected: { peer, _, message, _ in
        print("[swift] chat selected (ChatListItem.selected -> messageSelected): \(peer.debugDisplayTitle), last message: \(message.text)")
    })

    let now = Int32(Date().timeIntervalSince1970)
    var items: [ListViewInsertItem] = []
    for (i, chat) in samples.enumerated() {
        let id = chat.name == "Saved Messages" ? accountPeerId : peerId(Int64(100 + i), group: chat.isGroup)
        let peer: Peer = chat.name == "Saved Messages" ? me : makePeer(chat, id: id)
        let author: Peer = chat.outgoing != nil ? me : (chat.isGroup ? makePeer(SampleChat(name: "Maya Levi", text: "", minutesAgo: 0), id: peerId(Int64(500 + i))) : peer)
        var peers = SimpleDictionary<PeerId, Peer>()
        peers[peer.id] = peer
        peers[author.id] = author
        peers[me.id] = me
        let timestamp = now - Int32(chat.minutesAgo * 60)
        let messageId = MessageId(peerId: id, namespace: Namespaces.Message.Cloud, id: Int32(1000 + i))
        let message = Message(stableId: UInt32(i + 1), stableVersion: 0, id: messageId, globallyUniqueId: nil, groupingKey: nil, groupInfo: nil, threadId: nil, timestamp: timestamp, flags: chat.outgoing == nil ? [.Incoming] : [], tags: [], globalTags: [], localTags: [], customTags: [], forwardInfo: nil, author: author, text: chat.text, attributes: [], media: [], peers: peers, associatedMessages: SimpleDictionary(), associatedMessageIds: [], associatedMedia: [:], associatedThreadInfo: nil, associatedStories: [:])
        let maxOutgoingRead: Int32 = chat.outgoing == true ? messageId.id : 0
        let readState = CombinedPeerReadState(states: [(Namespaces.Message.Cloud, .idBased(maxIncomingReadId: chat.unread > 0 ? 0 : messageId.id, maxOutgoingReadId: maxOutgoingRead, maxKnownId: messageId.id, count: chat.unread, markedUnread: false))])
        let index = EngineChatList.Item.Index.chatList(ChatListIndex(pinningIndex: chat.pinned ? UInt16(i) : nil, messageIndex: MessageIndex(id: messageId, timestamp: timestamp)))
        let content = ChatListItemContent.peer(ChatListItemContent.PeerData(
            messages: [EngineMessage(message)],
            peer: EngineRenderedPeer(peer: EnginePeer(peer)),
            threadInfo: nil,
            combinedReadState: EnginePeerReadCounters(state: readState, isMuted: chat.muted),
            isRemovedFromTotalUnreadCount: chat.muted,
            presence: chat.online ? EnginePeer.Presence(status: .present(until: Int32.max), lastActivity: now) : nil,
            hasUnseenMentions: false, hasUnseenReactions: false, hasUnseenPollVotes: false,
            draftState: nil, mediaDraftContentType: nil, inputActivities: nil, promoInfo: nil,
            ignoreUnreadBadge: false, displayAsMessage: false, hasFailedMessages: false,
            forumTopicData: nil, topForumTopicItems: [], autoremoveTimeout: nil, storyState: nil,
            requiresPremiumForMessaging: false, displayAsTopicList: false, tags: []
        ))
        let item = ChatListItem(presentationData: presentationData, context: context, chatListLocation: .chatList(groupId: .root), filterData: nil, index: index, content: content, editing: false, hasActiveRevealControls: false, selected: false, header: nil, enabledContextActions: nil, hiddenOffset: false, interaction: interaction)
        items.append(ListViewInsertItem(index: i, previousIndex: nil, item: item, directionHint: nil))
    }

    let window = UIWindow(frame: screen)
    window.backgroundColor = theme.chatList.backgroundColor
    let root = ASDisplayNode()
    root.frame = screen
    root.backgroundColor = theme.chatList.backgroundColor

    let headerHeight: CGFloat = 59.0 + 44.0
    let header = ASDisplayNode()
    header.backgroundColor = theme.rootController.navigationBar.opaqueBackgroundColor
    header.frame = CGRect(x: 0, y: 0, width: screen.width, height: headerHeight)
    root.addSubnode(header)
    let title = ImmediateTextNode()
    title.attributedText = NSAttributedString(string: strings.DialogList_Title, font: Font.semibold(17.0), textColor: theme.rootController.navigationBar.primaryTextColor)
    let titleSize = title.updateLayout(CGSize(width: 200.0, height: 44.0))
    title.frame = CGRect(origin: CGPoint(x: floor((screen.width - titleSize.width) / 2.0), y: 59.0 + floor((44.0 - titleSize.height) / 2.0)), size: titleSize)
    header.addSubnode(title)
    let headerSeparator = ASDisplayNode()
    headerSeparator.isLayerBacked = true
    headerSeparator.backgroundColor = theme.rootController.navigationBar.separatorColor
    headerSeparator.frame = CGRect(x: 0, y: headerHeight - UIScreenPixel, width: screen.width, height: UIScreenPixel)
    header.addSubnode(headerSeparator)

    let listView = ListViewImpl()
    listView.frame = CGRect(x: 0, y: headerHeight, width: screen.width, height: screen.height - headerHeight)
    root.insertSubnode(listView, at: 0)
    listView.transaction(deleteIndices: [], insertIndicesAndItems: items, updateIndicesAndItems: [], options: ListViewDeleteAndInsertOptions([.Synchronous, .LowLatency]),
                         updateSizeAndInsets: ListViewUpdateSizeAndInsets(size: listView.frame.size, insets: UIEdgeInsets(top: 0, left: 0, bottom: 34.0, right: 0), duration: 0.0, curve: .Default(duration: nil)),
                         updateOpaqueState: nil)

    window.addSubview(root.view)
    window.makeKeyAndVisible()
    WebHost.annotate = { $0.asyncdisplaykit_node.map { String(describing: type(of: $0)) } }
    chatListRetain = [window, root, listView, theme, context, interaction]

    var realRows = 0, otherRows = 0
    listView.forEachItemNode { node in
        if node is ChatListItemNode { realRows += 1 } else { otherRows += 1 }
    }
    print("[swift] chat list started with \(samples.count) chats: \(realRows) rows are ChatListUI.ChatListItemNode (real Telegram cell), \(otherRows) other")
}
