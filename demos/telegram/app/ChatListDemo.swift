// Swiftboard web port (GPL, demo glue): a chat list made of Telegram's real pieces. Display's ListView (scrolling,
// recycling, highlight, selection), Telegram's default day theme and chat-list resources (TelegramPresentationData),
// ChatListBadgeNode (unread badges), PeerOnlineMarkerNode and TextNode. The row layout follows ChatListItemNode's
// metrics; ChatListItemNode itself still needs the TelegramCore/AccountContext data layer (see PROGRESS.md).
// Compiled into the ChatListUI module so it can use Telegram's internal ChatListBadgeNode.
import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import TelegramPresentationData
import PeerOnlineMarkerNode
import ComponentFlow // CGRect.center for ChatListBadgeNode (upstream gets it through other ChatListUI files)

public struct DemoChat {
    public var name: String
    public var text: String
    public var time: String
    public var unread: Int
    public var muted: Bool
    public var pinned: Bool
    public var online: Bool
    public var outgoingRead: Bool?
    public init(name: String, text: String, time: String, unread: Int = 0, muted: Bool = false, pinned: Bool = false, online: Bool = false, outgoingRead: Bool? = nil) {
        self.name = name; self.text = text; self.time = time; self.unread = unread; self.muted = muted; self.pinned = pinned; self.online = online; self.outgoingRead = outgoingRead
    }
}

// Telegram's avatar gradient pairs (AvatarNode's peer colors: red, orange, violet, green, cyan, blue, pink)
private let avatarGradients: [(UInt32, UInt32)] = [(0xFF885E, 0xFF516A), (0xFFCD6A, 0xFFA85C), (0x82B1FF, 0x665FFF), (0xA0DE7E, 0x54CB68), (0x53EDD6, 0x28C9B7), (0x72D5FD, 0x2A9EF1), (0xE0A2F3, 0xD669ED)]

private func avatarImage(name: String, index: Int, diameter: CGFloat) -> UIImage? {
    let initials = name.split(separator: " ").prefix(2).compactMap { $0.first.map(String.init) }.joined().uppercased()
    let (top, bottom) = avatarGradients[index % avatarGradients.count]
    return generateImage(CGSize(width: diameter, height: diameter), rotatedContext: { size, context in
        context.clear(CGRect(origin: .zero, size: size))
        context.addEllipse(in: CGRect(origin: .zero, size: size))
        context.clip()
        let colors = [UIColor(rgb: top).cgColor, UIColor(rgb: bottom).cgColor] as NSArray
        var locations: [CGFloat] = [0.0, 1.0]
        let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: &locations)!
        context.drawLinearGradient(gradient, start: CGPoint(), end: CGPoint(x: 0.0, y: size.height), options: [])
        let font = avatarPlaceholderFont(size: floor(diameter * 0.4))
        let string = NSAttributedString(string: initials, font: font, textColor: .white)
        let line = CTLineCreateWithAttributedString(string)
        let width = CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
        // rotatedContext is y-down (UIKit space): flip glyphs, baseline at the vertical center plus half the cap height
        context.textMatrix = CGAffineTransform(scaleX: 1.0, y: -1.0)
        context.textPosition = CGPoint(x: floor((size.width - width) / 2.0), y: floor((size.height + font.capHeight) / 2.0))
        CTLineDraw(line, context)
    })
}
private func avatarPlaceholderFont(size: CGFloat) -> UIFont { UIFont.systemFont(ofSize: size, weight: .semibold) }

public final class DemoChatListItem: ListViewItem {
    let theme: PresentationTheme
    let chat: DemoChat
    let index: Int
    let action: (DemoChat) -> Void
    public init(theme: PresentationTheme, chat: DemoChat, index: Int, action: @escaping (DemoChat) -> Void) {
        self.theme = theme; self.chat = chat; self.index = index; self.action = action
    }
    public var selectable: Bool { true }
    public var approximateHeight: CGFloat { 76.0 }
    public var neighborDescriptor: AnyEquatable { .noNeighborInfluence }
    public func selected(listView: ListView) {
        listView.clearHighlightAnimated(true)
        action(chat)
    }
    public func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, neighbors: ListViewItemNeighbors, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = DemoChatListItemNode()
            let (layout, apply) = node.asyncLayout()(self, params, neighbors.next == nil)
            node.contentSize = layout.contentSize
            node.insets = layout.insets
            Queue.mainQueue().async {
                completion(node, { (nil, { _ in apply() }) })
            }
        }
    }
    public func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, neighbors: ListViewItemNeighbors, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping (ListViewItemApply) -> Void) -> Void) {
        Queue.mainQueue().async {
            guard let nodeValue = node() as? DemoChatListItemNode else { return }
            let makeLayout = nodeValue.asyncLayout()
            async {
                let (layout, apply) = makeLayout(self, params, neighbors.next == nil)
                Queue.mainQueue().async { completion(layout, { _ in apply() }) }
            }
        }
    }
}

final class DemoChatListItemNode: ListViewItemNode {
    private let backgroundNode = ASDisplayNode()
    private let highlightedBackgroundNode = ASDisplayNode()
    private let avatarNode = ASImageNode()
    private let onlineNode = PeerOnlineMarkerNode()
    private let titleNode = TextNode()
    private let textNode = TextNode()
    private let dateNode = TextNode()
    private let statusNode = ASImageNode()
    private let mutedIconNode = ASImageNode()
    private let pinnedIconNode = ASImageNode()
    private let badgeNode = ChatListBadgeNode()
    private let separatorNode = ASDisplayNode()
    private var item: DemoChatListItem?

    init() {
        super.init(layerBacked: false)
        backgroundNode.isLayerBacked = true
        highlightedBackgroundNode.isLayerBacked = true
        highlightedBackgroundNode.alpha = 0.0
        separatorNode.isLayerBacked = true
        for n in [avatarNode, statusNode, mutedIconNode, pinnedIconNode] { n.displaysAsynchronously = false; n.isLayerBacked = true }
        addSubnode(backgroundNode)
        addSubnode(highlightedBackgroundNode)
        addSubnode(avatarNode)
        addSubnode(onlineNode)
        addSubnode(titleNode)
        addSubnode(textNode)
        addSubnode(dateNode)
        addSubnode(statusNode)
        addSubnode(mutedIconNode)
        addSubnode(pinnedIconNode)
        addSubnode(badgeNode)
        addSubnode(separatorNode)
    }

    override func setHighlighted(_ highlighted: Bool, at point: CGPoint, animated: Bool) {
        super.setHighlighted(highlighted, at: point, animated: animated)
        highlightedBackgroundNode.alpha = highlighted ? 1.0 : 0.0
    }

    func asyncLayout() -> (DemoChatListItem, ListViewItemLayoutParams, Bool) -> (ListViewItemNodeLayout, () -> Void) {
        let makeTitle = TextNode.asyncLayout(titleNode)
        let makeText = TextNode.asyncLayout(textNode)
        let makeDate = TextNode.asyncLayout(dateNode)
        let makeBadge = badgeNode.asyncLayout()
        let makeOnline = onlineNode.asyncLayout()
        return { [weak self] item, params, last in
            let theme = item.theme.chatList
            let chat = item.chat
            // ChatListItemNode metrics at the default font size (17 pt base)
            let height: CGFloat = 76.0
            let avatarDiameter: CGFloat = 60.0
            let leftInset: CGFloat = params.leftInset + 10.0 + avatarDiameter + 10.0
            let rightInset: CGFloat = params.rightInset + 10.0
            let titleFont = Font.medium(16.0)
            let textFont = Font.regular(15.0)
            let dateFont = Font.regular(14.0)
            let badgeFont = Font.regular(14.0)

            let (dateLayout, dateApply) = makeDate(TextNodeLayoutArguments(attributedString: NSAttributedString(string: chat.time, font: dateFont, textColor: theme.dateTextColor), maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: 100.0, height: 30.0)))
            var statusImage: UIImage?
            if let read = chat.outgoingRead { statusImage = read ? PresentationResourcesChatList.doubleCheckImage(item.theme) : PresentationResourcesChatList.singleCheckImage(item.theme) }
            let statusWidth = statusImage.map { $0.size.width + 2.0 } ?? 0.0
            let mutedImage = chat.muted ? PresentationResourcesChatList.mutedIcon(item.theme) : nil
            let titleWidth = params.width - leftInset - rightInset - dateLayout.size.width - statusWidth - 6.0 - (mutedImage != nil ? 18.0 : 0.0)
            let (titleLayout, titleApply) = makeTitle(TextNodeLayoutArguments(attributedString: NSAttributedString(string: chat.name, font: titleFont, textColor: theme.titleColor), maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: max(1.0, titleWidth), height: 30.0)))

            let badgeContent: ChatListBadgeContent = chat.unread > 0 ? .text(NSAttributedString(string: "\(chat.unread)", font: badgeFont, textColor: chat.muted ? theme.unreadBadgeInactiveTextColor : theme.unreadBadgeActiveTextColor)) : .none
            let badgeBackground = chat.muted ? PresentationResourcesChatList.badgeBackgroundInactive(item.theme, diameter: 20.0) : PresentationResourcesChatList.badgeBackgroundActive(item.theme, diameter: 20.0)
            let (badgeSize, badgeApply) = makeBadge(CGSize(width: 100.0, height: 20.0), 20.0, badgeFont, badgeBackground, badgeContent)
            let pinnedImage = (chat.pinned && chat.unread == 0) ? PresentationResourcesChatList.badgeBackgroundPinned(item.theme, diameter: 20.0) : nil
            let badgeAreaWidth = chat.unread > 0 ? badgeSize.width + 6.0 : (pinnedImage != nil ? 26.0 : 0.0)

            let (textLayout, textApply) = makeText(TextNodeLayoutArguments(attributedString: NSAttributedString(string: chat.text, font: textFont, textColor: theme.messageTextColor), maximumNumberOfLines: 2, truncationType: .end, constrainedSize: CGSize(width: params.width - leftInset - rightInset - badgeAreaWidth, height: 40.0)))
            let (onlineSize, onlineApply) = makeOnline(chat.online, false)

            let layout = ListViewItemNodeLayout(contentSize: CGSize(width: params.width, height: height), insets: UIEdgeInsets())
            return (layout, {
                guard let self else { return }
                self.item = item
                let bounds = CGRect(origin: .zero, size: layout.contentSize)
                self.backgroundNode.backgroundColor = chat.pinned ? theme.pinnedItemBackgroundColor : theme.itemBackgroundColor
                self.backgroundNode.frame = bounds
                self.highlightedBackgroundNode.backgroundColor = theme.itemHighlightedBackgroundColor
                self.highlightedBackgroundNode.frame = bounds
                self.avatarNode.image = avatarImage(name: chat.name, index: item.index, diameter: avatarDiameter)
                self.avatarNode.frame = CGRect(x: params.leftInset + 10.0, y: floor((height - avatarDiameter) / 2.0), width: avatarDiameter, height: avatarDiameter)
                self.onlineNode.setImage(PresentationResourcesChatList.recentStatusOnlineIcon(item.theme, state: .regular), color: nil, transition: .immediate)
                onlineApply(false)
                self.onlineNode.frame = CGRect(origin: CGPoint(x: self.avatarNode.frame.maxX - onlineSize.width - 2.0, y: self.avatarNode.frame.maxY - onlineSize.height - 2.0), size: onlineSize)

                let _ = titleApply()
                self.titleNode.frame = CGRect(origin: CGPoint(x: leftInset, y: 8.0), size: titleLayout.size)
                if let mutedImage {
                    self.mutedIconNode.image = mutedImage
                    self.mutedIconNode.frame = CGRect(origin: CGPoint(x: leftInset + titleLayout.size.width + 3.0, y: 8.0 + floor((titleLayout.size.height - mutedImage.size.height) / 2.0)), size: mutedImage.size)
                }
                self.mutedIconNode.isHidden = mutedImage == nil
                let _ = dateApply()
                self.dateNode.frame = CGRect(origin: CGPoint(x: params.width - rightInset - dateLayout.size.width, y: 10.0), size: dateLayout.size)
                if let statusImage {
                    self.statusNode.image = statusImage
                    self.statusNode.frame = CGRect(origin: CGPoint(x: self.dateNode.frame.minX - statusImage.size.width - 2.0, y: 12.0), size: statusImage.size)
                }
                self.statusNode.isHidden = statusImage == nil
                let _ = textApply()
                self.textNode.frame = CGRect(origin: CGPoint(x: leftInset, y: 31.0), size: textLayout.size)
                badgeApply(false, false)
                self.badgeNode.frame = CGRect(origin: CGPoint(x: params.width - rightInset - badgeSize.width, y: 38.0), size: badgeSize)
                self.pinnedIconNode.image = pinnedImage
                self.pinnedIconNode.isHidden = pinnedImage == nil
                if let pinnedImage { self.pinnedIconNode.frame = CGRect(origin: CGPoint(x: params.width - rightInset - pinnedImage.size.width, y: 38.0), size: pinnedImage.size) }
                self.separatorNode.backgroundColor = theme.itemSeparatorColor
                self.separatorNode.isHidden = last
                self.separatorNode.frame = CGRect(x: leftInset, y: height - UIScreenPixel, width: params.width - leftInset, height: UIScreenPixel)
            })
        }
    }
}

/// A window with Telegram's chat list over `chats`: a "Chats" header and Display's ListView.
public func makeDemoChatListWindow(chats: [DemoChat], onSelect: @escaping (DemoChat) -> Void) -> (UIWindow, [AnyObject]) {
    let screen = UIScreen.main.bounds
    let theme = makeDefaultDayPresentationTheme(serviceBackgroundColor: nil, day: false, preview: false)
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
    title.attributedText = NSAttributedString(string: "Chats", font: Font.semibold(17.0), textColor: theme.rootController.navigationBar.primaryTextColor)
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

    let items: [ListViewInsertItem] = chats.enumerated().map { i, chat in
        ListViewInsertItem(index: i, previousIndex: nil, item: DemoChatListItem(theme: theme, chat: chat, index: i, action: onSelect), directionHint: nil)
    }
    listView.transaction(deleteIndices: [], insertIndicesAndItems: items, updateIndicesAndItems: [], options: ListViewDeleteAndInsertOptions([.Synchronous, .LowLatency]),
                         updateSizeAndInsets: ListViewUpdateSizeAndInsets(size: listView.frame.size, insets: UIEdgeInsets(top: 0, left: 0, bottom: 34.0, right: 0), duration: 0.0, curve: .Default(duration: nil)),
                         updateOpaqueState: nil)

    window.addSubview(root.view)
    window.makeKeyAndVisible()
    return (window, [root, listView, theme])
}
