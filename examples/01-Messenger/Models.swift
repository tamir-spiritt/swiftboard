import SwiftUI

struct Chat: Identifiable, Hashable {
    let id: Int
    let name: String
    let lastMessage: String
    var sender: String? = nil
    let time: String
    var unread: Int = 0
    var muted: Bool = false
    var pinned: Bool = false
    var online: Bool = false
    var read: Bool = false
    var subtitle: String = "last seen recently"
    let colorIndex: Int

    var initials: String {
        let parts = name.split(separator: " ")
        let letters = parts.prefix(2).compactMap { $0.first }
        return String(letters).uppercased()
    }
}

struct Message: Identifiable, Hashable {
    let id: Int
    var author: String? = nil
    let text: String
    let time: String
    var outgoing: Bool = false
    var colorIndex: Int = 0
}

struct Contact: Identifiable, Hashable {
    let id: Int
    let name: String
    let status: String
    var online: Bool = false
    let colorIndex: Int

    var initials: String {
        let parts = name.split(separator: " ")
        let letters = parts.prefix(2).compactMap { $0.first }
        return String(letters).uppercased()
    }
}

struct CallItem: Identifiable, Hashable {
    let id: Int
    let name: String
    let detail: String
    let date: String
    var missed: Bool = false
    var outgoing: Bool = false
    var video: Bool = false
    let colorIndex: Int
}

enum SampleData {
    static let chats: [Chat] = [
        Chat(id: 1, name: "Design Team", lastMessage: "Pushed the new badge styles 🎨", sender: "Ada Park", time: "9:39 AM", unread: 3, subtitle: "5 members, 2 online", colorIndex: 0),
        Chat(id: 2, name: "Ada Park", lastMessage: "See you at the review at 3?", time: "9:36 AM", pinned: true, online: true, subtitle: "online", colorIndex: 1),
        Chat(id: 3, name: "Ben Okafor", lastMessage: "Sent you the specs for the settings screen", time: "9:20 AM", unread: 1, colorIndex: 5),
        Chat(id: 4, name: "Chloe Martin", lastMessage: "Thanks! Looks great.", time: "8:56 AM", read: true, colorIndex: 6),
        Chat(id: 5, name: "Diego Alvarez", lastMessage: "Can we move standup to 10?", time: "8:36 AM", unread: 2, colorIndex: 1),
        Chat(id: 6, name: "Weekend Hikes", lastMessage: "Weather looks perfect this weekend", sender: "Hana Sato", time: "8:01 AM", unread: 14, muted: true, subtitle: "12 members", colorIndex: 5),
        Chat(id: 7, name: "Emma Laurent", lastMessage: "Sounds good, 12:30?", time: "Wed", read: true, colorIndex: 7),
        Chat(id: 8, name: "Farah Khan", lastMessage: "Let me know what you think!", time: "Wed", unread: 5, muted: true, colorIndex: 3),
        Chat(id: 9, name: "George Ito", lastMessage: "The prototype is live 🚀", time: "Tue", colorIndex: 2),
        Chat(id: 10, name: "Product Updates", lastMessage: "Version 11.4 is rolling out today", time: "Mon", colorIndex: 4),
    ]

    static let messages: [Message] = [
        Message(id: 1, author: "Ben Okafor", text: "Morning! Review is at 3pm today.", time: "9:11 AM", colorIndex: 5),
        Message(id: 2, text: "I'll bring the new chat list mocks.", time: "9:12 AM", outgoing: true),
        Message(id: 3, author: "Chloe Martin", text: "Can we look at the onboarding flow too?", time: "9:16 AM", colorIndex: 6),
        Message(id: 4, author: "Diego Alvarez", text: "Sure, adding it to the agenda.", time: "9:26 AM", colorIndex: 1),
        Message(id: 5, author: "Ada Park", text: "Pushed the new badge styles 🎨", time: "9:39 AM", colorIndex: 0),
    ]

    static let contacts: [Contact] = [
        Contact(id: 1, name: "Ada Park", status: "online", online: true, colorIndex: 1),
        Contact(id: 2, name: "Ben Okafor", status: "last seen 5 minutes ago", colorIndex: 5),
        Contact(id: 3, name: "Chloe Martin", status: "last seen recently", colorIndex: 6),
        Contact(id: 4, name: "Diego Alvarez", status: "online", online: true, colorIndex: 1),
        Contact(id: 5, name: "Emma Laurent", status: "last seen yesterday at 21:40", colorIndex: 7),
        Contact(id: 6, name: "Farah Khan", status: "last seen recently", colorIndex: 3),
        Contact(id: 7, name: "George Ito", status: "last seen within a week", colorIndex: 2),
        Contact(id: 8, name: "Hana Sato", status: "online", online: true, colorIndex: 5),
    ]

    static let calls: [CallItem] = [
        CallItem(id: 1, name: "Ada Park", detail: "Outgoing", date: "9:02 AM", outgoing: true, colorIndex: 1),
        CallItem(id: 2, name: "Diego Alvarez", detail: "Missed", date: "Yesterday", missed: true, colorIndex: 1),
        CallItem(id: 3, name: "Chloe Martin", detail: "Incoming (12 min)", date: "Yesterday", video: true, colorIndex: 6),
        CallItem(id: 4, name: "Ben Okafor", detail: "Outgoing (3 min)", date: "Tuesday", outgoing: true, colorIndex: 5),
        CallItem(id: 5, name: "Farah Khan", detail: "Missed", date: "Monday", missed: true, colorIndex: 3),
        CallItem(id: 6, name: "Emma Laurent", detail: "Incoming (41 min)", date: "Sunday", colorIndex: 7),
    ]
}
