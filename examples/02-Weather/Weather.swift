import SwiftUI

struct Day: Identifiable {
    let id: Int
    let name: String
    let icon: String
    let high: Int
    let low: Int
}

struct WeatherView: View {
    @State private var celsius = true
    let days = [
        Day(id: 0, name: "Today", icon: "sun.max", high: 24, low: 15),
        Day(id: 1, name: "Tue", icon: "cloud", high: 21, low: 14),
        Day(id: 2, name: "Wed", icon: "cloud", high: 19, low: 12),
        Day(id: 3, name: "Thu", icon: "sun.max", high: 26, low: 17),
    ]

    func fmt(_ c: Int) -> String {
        celsius ? "\(c)°" : "\(c * 9 / 5 + 32)°"
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0x4A90E2), Color(hex: 0x87CEFA)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            VStack(spacing: 8) {
                Text("London").font(.system(size: 34, weight: .medium))
                Text(fmt(24)).font(.system(size: 96, weight: .thin))
                Text("Mostly Sunny").font(.title3)
                VStack(spacing: 0) {
                    ForEach(days) { d in
                        HStack {
                            Text(d.name).frame(width: 70, alignment: .leading)
                            Image(systemName: d.icon)
                            Spacer()
                            Text(fmt(d.low)).foregroundStyle(.white.opacity(0.7))
                            Text(fmt(d.high))
                        }
                        .padding(.vertical, 10)
                    }
                }
                .padding(.horizontal, 20)
                .background(.white.opacity(0.15), in: RoundedRectangle(cornerRadius: 20))
                .padding()
                Button(celsius ? "Show °F" : "Show °C") { celsius.toggle() }
                    .padding(.horizontal, 20).padding(.vertical, 10)
                    .background(.white.opacity(0.25), in: Capsule())
            }
            .foregroundStyle(.white)
        }
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
    }
}

#Preview("Weather") {
    WeatherView()
}
