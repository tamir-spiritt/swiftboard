import SwiftUI

struct ChatListView: View {
    @State private var chats = SampleData.chats
    @State private var search = ""

    var filtered: [Chat] {
        search.isEmpty ? chats : chats.filter { $0.name.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 0) {
                    SearchField(text: $search)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                    ForEach(filtered) { chat in
                        NavigationLink {
                            ChatView(chat: chat)
                        } label: {
                            ChatRow(chat: chat)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle("Chats")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Edit") {}
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                    } label: {
                        Image(systemName: "square.and.pencil")
                    }
                }
            }
        }
    }
}

struct SearchField: View {
    @Binding var text: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search", text: $text)
        }
        .font(.system(size: 17))
        .padding(.horizontal, 12)
        .frame(height: 38)
        .background(Color(.systemGray6), in: Capsule())
    }
}

struct ChatRow: View {
    let chat: Chat

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                AvatarView(initials: chat.initials, colorIndex: chat.colorIndex)
                if chat.online {
                    Circle()
                        .fill(Color.tgOnline)
                        .frame(width: 14, height: 14)
                        .overlay(Circle().stroke(Color.white, lineWidth: 2.5))
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(chat.name)
                        .font(.system(size: 17, weight: .semibold))
                        .lineLimit(1)
                    if chat.muted {
                        Image(systemName: "speaker.slash.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if chat.read {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Color.tgOnline)
                    }
                    Text(chat.time)
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                }
                HStack(alignment: .top, spacing: 8) {
                    VStack(alignment: .leading, spacing: 1) {
                        if let sender = chat.sender {
                            Text(sender)
                                .font(.system(size: 15))
                                .lineLimit(1)
                        }
                        Text(chat.lastMessage)
                            .font(.system(size: 15))
                            .foregroundStyle(.secondary)
                            .lineLimit(chat.sender == nil ? 2 : 1)
                    }
                    Spacer()
                    if chat.unread > 0 {
                        Text("\(chat.unread)")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 7)
                            .frame(minWidth: 22, minHeight: 22)
                            .background(chat.muted ? Color.tgMutedBadge : Color.tgBlue, in: Capsule())
                    } else if chat.pinned {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(Color(.systemGray2))
                            .rotationEffect(.degrees(45))
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
}

#Preview("Chat List") {
    RootView()
}
