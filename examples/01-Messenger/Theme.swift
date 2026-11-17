import SwiftUI

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }

    static let tgBlue = Color(hex: 0x3390EC)
    static let tgOutgoing = Color(hex: 0xE1FFC7)
    static let tgOutgoingMeta = Color(hex: 0x4FAE4E)
    static let tgOnline = Color(hex: 0x34C759)
    static let tgMutedBadge = Color(hex: 0xAEAEB2)
}

enum Theme {
    static func avatar(_ index: Int) -> [Color] {
        let palettes: [[Color]] = [
            [Color(hex: 0x72D5FD), Color(hex: 0x2A9EF1)],
            [Color(hex: 0xA0DE7E), Color(hex: 0x54CB68)],
            [Color(hex: 0xFF885E), Color(hex: 0xFF516A)],
            [Color(hex: 0xFFCD6A), Color(hex: 0xFFA85C)],
            [Color(hex: 0xE0A2F3), Color(hex: 0xD669ED)],
            [Color(hex: 0x53EDD6), Color(hex: 0x28C9B7)],
            [Color(hex: 0x82B1FF), Color(hex: 0x665FFF)],
            [Color(hex: 0xFF8AAC), Color(hex: 0xF0577F)],
        ]
        return palettes[index % palettes.count]
    }

    static func nameColor(_ index: Int) -> Color {
        let colors: [Color] = [
            Color(hex: 0x2A9EF1), Color(hex: 0x3DAE4C), Color(hex: 0xE5533B), Color(hex: 0xE08A1E),
            Color(hex: 0xB55BD0), Color(hex: 0x1FA99A), Color(hex: 0x5C67E0), Color(hex: 0xD84876),
        ]
        return colors[index % colors.count]
    }
}

struct AvatarView: View {
    let initials: String
    let colorIndex: Int
    var size: CGFloat = 56

    var body: some View {
        Circle()
            .fill(LinearGradient(colors: Theme.avatar(colorIndex), startPoint: .top, endPoint: .bottom))
            .frame(width: size, height: size)
            .overlay {
                Text(initials)
                    .font(.system(size: size * 0.38, weight: .semibold))
                    .foregroundStyle(.white)
            }
    }
}
