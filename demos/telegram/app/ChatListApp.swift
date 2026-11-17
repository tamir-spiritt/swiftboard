// Browser demo of Telegram's chat list (layer 3): ten sample chats in Display's ListView.
import Foundation
import UIKit
import AsyncDisplayKit
import Display
import ChatListUI

nonisolated(unsafe) var chatListRetain: [AnyObject] = []

@_cdecl("app_start")
public func app_start() {
    let chats: [DemoChat] = [
        DemoChat(name: "Saved Messages", text: "Swiftboard: Telegram's real Display + ListView on WebAssembly", time: "11:42", pinned: true, outgoingRead: true),
        DemoChat(name: "Pavel Durov", text: "Ship it 🚀", time: "11:30", unread: 2, pinned: true, online: true),
        DemoChat(name: "Design Team", text: "Maya: the new chat list cells look right at every font size, checked against iOS", time: "10:58", unread: 14),
        DemoChat(name: "Alex Chen", text: "Running the Swift compiler output in a browser canvas is wild", time: "10:41", online: true, outgoingRead: false),
        DemoChat(name: "Telegram Tips", text: "Swipe a chat left to archive it, right to mark it as read.", time: "09:15", unread: 1, muted: true),
        DemoChat(name: "Family", text: "Mom: Dinner at 7?", time: "Tue", unread: 3, muted: true),
        DemoChat(name: "Nora Weiss", text: "Photo", time: "Mon", outgoingRead: true),
        DemoChat(name: "Swift Developers", text: "Ben: WASI reactor builds work with -mexec-model=reactor", time: "Sun", unread: 128, muted: true),
        DemoChat(name: "Liam O'Brien", text: "Sounds good, talk tomorrow", time: "Sat", online: true, outgoingRead: true),
        DemoChat(name: "Crypto Signals", text: "⚠️ Never share your recovery phrase", time: "Fri", muted: true),
    ]
    let (window, retain) = makeDemoChatListWindow(chats: chats, onSelect: { chat in
        print("[swift] chat selected: \(chat.name)")
    })
    WebHost.annotate = { $0.asyncdisplaykit_node.map { String(describing: type(of: $0)) } }
    chatListRetain = [window] + retain
    print("[swift] chat list started with \(chats.count) chats")
}
