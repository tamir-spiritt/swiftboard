import SwiftUI

struct CalculatorView: View {
    @State private var display = "0"
    @State private var stored: Double = 0
    @State private var op: String? = nil
    @State private var fresh = true

    let rows: [[String]] = [
        ["AC", "±", "%", "÷"],
        ["7", "8", "9", "×"],
        ["4", "5", "6", "−"],
        ["1", "2", "3", "+"],
        ["0", ".", "="],
    ]

    var body: some View {
        VStack(spacing: 12) {
            Spacer()
            HStack {
                Spacer()
                Text(display)
                    .font(.system(size: 88, weight: .light))
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }
            .padding(.horizontal, 24)
            ForEach(rows, id: \.self) { row in
                HStack(spacing: 12) {
                    ForEach(row, id: \.self) { key in
                        Button {
                            press(key)
                        } label: {
                            Text(key)
                                .font(.system(size: 34, weight: .medium))
                                .foregroundStyle(fg(key))
                                .frame(width: key == "0" ? 172 : 80, height: 80)
                                .background(bg(key), in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
        .preferredColorScheme(.dark)
    }

    func bg(_ k: String) -> Color {
        if ["÷", "×", "−", "+", "="].contains(k) { return op == k && fresh ? .white : .orange }
        if ["AC", "±", "%"].contains(k) { return Color(white: 0.65) }
        return Color(white: 0.2)
    }

    func fg(_ k: String) -> Color {
        if ["AC", "±", "%"].contains(k) { return .black }
        if op == k && fresh { return .orange }
        return .white
    }

    func press(_ k: String) {
        switch k {
        case "AC":
            display = "0"; stored = 0; op = nil; fresh = true
        case "±":
            if let v = Double(display) { display = format(-v) }
        case "%":
            if let v = Double(display) { display = format(v / 100) }
        case "÷", "×", "−", "+":
            compute()
            op = k
            fresh = true
        case "=":
            compute()
            op = nil
            fresh = true
        case ".":
            if fresh { display = "0."; fresh = false } else if !display.contains(".") { display += "." }
        default:
            if fresh || display == "0" { display = k; fresh = false } else { display += k }
        }
    }

    func compute() {
        let cur = Double(display) ?? 0
        if let o = op, !fresh {
            var r = stored
            switch o {
            case "+": r = stored + cur
            case "−": r = stored - cur
            case "×": r = stored * cur
            default: r = cur == 0 ? 0 : stored / cur
            }
            display = format(r)
            stored = r
        } else {
            stored = cur
        }
    }

    func format(_ v: Double) -> String {
        if v == v.rounded() && abs(v) < 1e12 { return String(Int(v)) }
        return String(format: "%.6g", v)
    }
}

#Preview("Calculator") {
    CalculatorView()
}
