import SwiftUI

struct ChatView: View {
    let chat: Chat
    @State private var messages: [Message] = SampleData.messages
    @State private var draft = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 6) {
                DateChip(text: "Today")
                ForEach(messages) { message in
                    MessageBubble(message: message)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 10)
        }
        .defaultScrollAnchor(.bottom)
        .background {
            ChatWallpaper()
        }
        .safeAreaInset(edge: .bottom) {
            InputBar(text: $draft, onSend: send)
        }
        .safeAreaInset(edge: .top) {
            header
        }
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
    }

    var header: some View {
        HStack(spacing: 10) {
            Button {
                dismiss()
            } label: {
                HStack(spacing: 2) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                    Text("3")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundStyle(.primary)
                .frame(width: 56, height: 44)
                .background(.regularMaterial, in: Capsule())
            }
            .buttonStyle(.plain)
            Spacer()
            VStack(spacing: 1) {
                Text(chat.name)
                    .font(.system(size: 16, weight: .semibold))
                    .lineLimit(1)
                Text(chat.subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 18)
            .frame(height: 44)
            .background(.regularMaterial, in: Capsule())
            Spacer()
            AvatarView(initials: chat.initials, colorIndex: chat.colorIndex, size: 44)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 6)
    }

    func send() {
        let text = draft.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        messages.append(Message(id: messages.count + 100, text: text, time: "9:41 AM", outgoing: true))
        draft = ""
    }
}

struct DateChip: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color.black.opacity(0.18), in: Capsule())
            .padding(.vertical, 6)
    }
}

struct MessageBubble: View {
    let message: Message

    var body: some View {
        HStack(alignment: .bottom, spacing: 6) {
            if message.outgoing {
                Spacer(minLength: 56)
            } else {
                AvatarView(initials: initials, colorIndex: message.colorIndex, size: 32)
            }
            VStack(alignment: .leading, spacing: 2) {
                if let author = message.author {
                    Text(author)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.nameColor(message.colorIndex))
                }
                HStack(alignment: .bottom, spacing: 8) {
                    Text(message.text)
                        .font(.system(size: 17))
                        .foregroundStyle(Color.black)
                    HStack(spacing: 2) {
                        Text(message.time)
                            .font(.system(size: 11))
                        if message.outgoing {
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .bold))
                        }
                    }
                    .foregroundStyle(message.outgoing ? Color.tgOutgoingMeta : Color.gray)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(message.outgoing ? Color.tgOutgoing : Color.white, in: RoundedRectangle(cornerRadius: 18))
            if !message.outgoing {
                Spacer(minLength: 48)
            }
        }
    }

    var initials: String {
        let parts = (message.author ?? "").split(separator: " ")
        return String(parts.prefix(2).compactMap { $0.first }).uppercased()
    }
}

struct InputBar: View {
    @Binding var text: String
    var onSend: () -> Void

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            CircleIcon(name: "paperclip")
            HStack(spacing: 8) {
                TextField("Message", text: $text, axis: .vertical)
                    .lineLimit(5)
                    .onSubmit(onSend)
                Image(systemName: "face.smiling")
                    .font(.system(size: 20))
                    .foregroundStyle(.secondary)
            }
            .font(.system(size: 17))
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .background(Color.white, in: Capsule())
            .shadow(color: Color.black.opacity(0.08), radius: 8, y: 2)
            if text.isEmpty {
                CircleIcon(name: "mic")
            } else {
                Button(action: onSend) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(Color.tgBlue, in: Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 6)
        .padding(.bottom, 4)
    }
}

struct CircleIcon: View {
    let name: String

    var body: some View {
        Image(systemName: name)
            .font(.system(size: 19))
            .foregroundStyle(.secondary)
            .frame(width: 44, height: 44)
            .background(Color.white, in: Circle())
            .shadow(color: Color.black.opacity(0.08), radius: 8, y: 2)
    }
}

struct ChatWallpaper: View {
    var body: some View {
        LinearGradient(
            colors: [Color(hex: 0xD0E4A0), Color(hex: 0x9FCB84), Color(hex: 0x86BE8C)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay {
            Image("chat-pattern")
                .resizable(resizingMode: .tile)
                .opacity(0.22)
        }
        .ignoresSafeArea()
    }
}

#Preview("Chat") {
    NavigationStack {
        ChatView(chat: SampleData.chats[0])
    }
}
