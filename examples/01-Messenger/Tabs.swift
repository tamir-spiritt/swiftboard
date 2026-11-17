import SwiftUI

enum AppTab: Hashable {
    case contacts, calls, chats, settings
}

struct RootView: View {
    @State private var tab: AppTab

    init(initialTab: AppTab = .chats) {
        _tab = State(initialValue: initialTab)
    }

    var body: some View {
        TabView(selection: $tab) {
            ContactsView()
                .tabItem { Label("Contacts", systemImage: "person.crop.circle") }
                .tag(AppTab.contacts)
            CallsView()
                .tabItem { Label("Calls", systemImage: "phone") }
                .tag(AppTab.calls)
            ChatListView()
                .tabItem { Label("Chats", systemImage: "bubble.left.and.bubble.right") }
                .badge(6)
                .tag(AppTab.chats)
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(AppTab.settings)
        }
        .tint(Color.tgBlue)
    }
}

struct ContactsView: View {
    var body: some View {
        NavigationStack {
            List {
                Label("Invite Friends", systemImage: "person.badge.plus")
                    .foregroundStyle(Color.tgBlue)
                Label("Find People Nearby", systemImage: "location")
                    .foregroundStyle(Color.tgBlue)
                ForEach(SampleData.contacts) { contact in
                    HStack(spacing: 12) {
                        AvatarView(initials: contact.initials, colorIndex: contact.colorIndex, size: 42)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(contact.name)
                                .font(.system(size: 17, weight: .semibold))
                            Text(contact.status)
                                .font(.system(size: 14))
                                .foregroundStyle(contact.online ? Color.tgBlue : Color.secondary)
                        }
                        Spacer()
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("Contacts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Sort") {}
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
    }
}

struct CallsView: View {
    @State private var missedOnly = false

    var calls: [CallItem] {
        missedOnly ? SampleData.calls.filter { $0.missed } : SampleData.calls
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(calls) { call in
                    HStack(spacing: 12) {
                        AvatarView(initials: String(call.name.prefix(1)), colorIndex: call.colorIndex, size: 42)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(call.name)
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(call.missed ? Color.red : Color.primary)
                            HStack(spacing: 4) {
                                Image(systemName: call.outgoing ? "phone.arrow.up.right" : "phone.arrow.down.left")
                                    .font(.system(size: 12))
                                Text(call.detail)
                                    .font(.system(size: 14))
                            }
                            .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(call.date)
                            .font(.system(size: 15))
                            .foregroundStyle(.secondary)
                        Image(systemName: call.video ? "video" : "info.circle")
                            .foregroundStyle(Color.tgBlue)
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("Calls")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 0) {
                        Button {
                            missedOnly = false
                        } label: {
                            Text("All")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.primary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 7)
                                .background(missedOnly ? Color.clear : Color.white, in: Capsule())
                        }
                        Button {
                            missedOnly = true
                        } label: {
                            Text("Missed")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.primary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 7)
                                .background(missedOnly ? Color.white : Color.clear, in: Capsule())
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(3)
                    .background(Color(.systemGray5), in: Capsule())
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button("Edit") {}
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                    } label: {
                        Image(systemName: "phone.badge.plus")
                    }
                }
            }
        }
    }
}

struct SettingsView: View {
    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(spacing: 6) {
                        AvatarView(initials: "NM", colorIndex: 6, size: 92)
                        Text("Nim Moore")
                            .font(.system(size: 24, weight: .semibold))
                        Text("+44 7700 900123 • @nim")
                            .font(.system(size: 15))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .listRowBackground(Color.clear)
                }
                Section {
                    SettingsRow(icon: "person.crop.circle.fill", color: Color(hex: 0xFF5E5E), title: "My Profile")
                    SettingsRow(icon: "bookmark.fill", color: Color(hex: 0x2A9EF1), title: "Saved Messages")
                    SettingsRow(icon: "phone.fill", color: Color(hex: 0x4CD964), title: "Recent Calls")
                    SettingsRow(icon: "laptopcomputer", color: Color(hex: 0xF6A030), title: "Devices", detail: "3")
                    SettingsRow(icon: "folder.fill", color: Color(hex: 0x2AB4F1), title: "Chat Folders")
                }
                Section {
                    SettingsRow(icon: "bell.fill", color: Color(hex: 0xFF3B30), title: "Notifications and Sounds")
                    SettingsRow(icon: "lock.fill", color: Color(hex: 0x8E8E93), title: "Privacy and Security")
                    SettingsRow(icon: "cylinder.split.1x2.fill", color: Color(hex: 0x4CD964), title: "Data and Storage")
                    SettingsRow(icon: "paintbrush.fill", color: Color(hex: 0x2A9EF1), title: "Appearance")
                    SettingsRow(icon: "globe", color: Color(hex: 0xA95CE3), title: "Language", detail: "English")
                }
                Section {
                    SettingsRow(icon: "star.fill", color: Color(hex: 0x8B5CF6), title: "Telegram Premium")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Edit") {}
                }
            }
        }
    }
}

struct SettingsRow: View {
    let icon: String
    let color: Color
    let title: String
    var detail: String? = nil

    var body: some View {
        NavigationLink {
            Text(title)
                .font(.title2)
                .navigationTitle(title)
        } label: {
            HStack(spacing: 14) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(color)
                    .frame(width: 30, height: 30)
                    .overlay {
                        Image(systemName: icon)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                Text(title)
                    .font(.system(size: 17))
                Spacer()
                if let detail {
                    Text(detail)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

#Preview("Contacts") {
    RootView(initialTab: .contacts)
}

#Preview("Calls") {
    RootView(initialTab: .calls)
}

#Preview("Settings") {
    RootView(initialTab: .settings)
}
