import SwiftUI

struct Track: Identifiable {
    let id: Int
    let title: String
    let artist: String
    let length: String
    let hue: Double
}

let tracks = [
    Track(id: 1, title: "Midnight Drive", artist: "Neon Coast", length: "3:42", hue: 0.62),
    Track(id: 2, title: "Paper Planes", artist: "Lumen", length: "4:05", hue: 0.08),
    Track(id: 3, title: "Low Tide", artist: "Harbor", length: "2:58", hue: 0.48),
    Track(id: 4, title: "Gold Rush", artist: "The Fevers", length: "3:21", hue: 0.12),
    Track(id: 5, title: "Static Bloom", artist: "Ivy & Iron", length: "5:10", hue: 0.85),
]

struct LibraryView: View {
    @State private var playing: Int? = 2

    var body: some View {
        NavigationStack {
            List {
                ForEach(tracks) { t in
                    HStack(spacing: 12) {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(hue: t.hue, saturation: 0.6, brightness: 0.9).gradient)
                            .frame(width: 52, height: 52)
                            .overlay(Image(systemName: "music.note").foregroundStyle(.white))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(t.title)
                                .font(.headline)
                                .foregroundStyle(playing == t.id ? Color.pink : Color.primary)
                            Text(t.artist).font(.subheadline).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(t.length).font(.subheadline).foregroundStyle(.secondary)
                    }
                    .onTapGesture { playing = t.id }
                }
            }
            .listStyle(.plain)
            .navigationTitle("Library")
            .safeAreaInset(edge: .bottom) {
                if let id = playing, let t = tracks.first(where: { $0.id == id }) {
                    MiniPlayer(track: t, onClose: { playing = nil })
                }
            }
        }
    }
}

struct MiniPlayer: View {
    let track: Track
    var onClose: () -> Void
    @State private var paused = false

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color(hue: track.hue, saturation: 0.6, brightness: 0.9))
                .frame(width: 40, height: 40)
            VStack(alignment: .leading) {
                Text(track.title).font(.subheadline.bold())
                Text(track.artist).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button { paused.toggle() } label: {
                Image(systemName: paused ? "play.fill" : "pause.fill").font(.title2)
            }
            Button(action: onClose) {
                Image(systemName: "xmark").font(.title3)
            }
        }
        .foregroundStyle(.primary)
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22))
        .shadow(color: .black.opacity(0.15), radius: 12, y: 4)
        .padding(.horizontal, 12)
    }
}

#Preview("Music") {
    LibraryView()
}
