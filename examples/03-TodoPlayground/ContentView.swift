import SwiftUI

enum Filter: String, CaseIterable, Identifiable {
    case all = "All", active = "Active", done = "Done"
    var id: String { rawValue }
}

struct Todo: Identifiable {
    let id = UUID()
    var title: String
    var done = false
}

struct ContentView: View {
    @State private var count = 0
    @State private var notify = true
    @State private var filter: Filter = .all
    @State private var todos = [Todo(title: "Ship engine"), Todo(title: "Write tweet", done: true), Todo(title: "Sleep")]
    @State private var newTitle = ""

    var visible: [Todo] {
        switch filter {
        case .all: return todos
        case .active: return todos.filter { !$0.done }
        case .done: return todos.filter { $0.done }
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Counter") {
                    HStack {
                        Text("Count: \(count)")
                            .font(.title2.bold())
                        Spacer()
                        Button("−") { count -= 1 }
                        Button("+") { count += 1 }
                    }
                    Toggle("Notifications", isOn: $notify)
                    if count > 3 {
                        Label("That's a lot of taps", systemImage: "flame.fill")
                            .foregroundStyle(.orange)
                    }
                }
                Section {
                    HStack(spacing: 8) {
                        ForEach(Filter.allCases) { f in
                            Text(f.rawValue)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(filter == f ? Color.blue : Color(.systemGray5), in: Capsule())
                                .foregroundStyle(filter == f ? .white : .primary)
                                .onTapGesture { filter = f }
                        }
                    }
                    ForEach(visible) { todo in
                        HStack {
                            Image(systemName: todo.done ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(todo.done ? .green : .secondary)
                            Text(todo.title)
                                .strikethrough(todo.done)
                        }
                        .onTapGesture { toggle(todo) }
                    }
                    HStack {
                        TextField("New todo", text: $newTitle)
                        Button("Add") {
                            todos.append(Todo(title: newTitle))
                            newTitle = ""
                        }
                        .disabled(newTitle.isEmpty)
                    }
                } header: {
                    Text("Todos (\(visible.count))")
                }
                Section {
                    ForEach(1...3, id: \.self) { i in
                        Text(String(format: "Row %02d · %.1f", i, Double(i) * 1.5))
                    }
                }
            }
            .navigationTitle("Playground")
        }
    }

    func toggle(_ todo: Todo) {
        if let i = todos.firstIndex(where: { $0.id == todo.id }) {
            todos[i].done.toggle()
        }
    }
}

#Preview {
    ContentView()
}
