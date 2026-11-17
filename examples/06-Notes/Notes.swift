import SwiftUI

struct Note: Identifiable {
    let id: Int
    var title: String
    var body: String
    var pinned = false
}

struct NotesView: View {
    @State private var notes = [
        Note(id: 1, title: "Launch checklist", body: "Record demo, write tweet, ship", pinned: true),
        Note(id: 2, title: "Groceries", body: "Milk, eggs, coffee"),
        Note(id: 3, title: "Ideas", body: "Design tool that runs real Swift in the browser"),
    ]
    @State private var query = ""
    @State private var draft = ""

    var shown: [Note] {
        let list = query.isEmpty ? notes : notes.filter { $0.title.localizedCaseInsensitiveContains(query) || $0.body.localizedCaseInsensitiveContains(query) }
        return list.filter { $0.pinned } + list.filter { !$0.pinned }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField("Search", text: $query)
                }
                Section("\(shown.count) Notes") {
                    ForEach(shown) { note in
                        NavigationLink {
                            NoteDetail(note: note)
                        } label: {
                            VStack(alignment: .leading, spacing: 3) {
                                HStack {
                                    if note.pinned {
                                        Image(systemName: "pin.fill").foregroundStyle(.orange).font(.caption)
                                    }
                                    Text(note.title).font(.headline)
                                }
                                Text(note.body).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                            }
                        }
                    }
                }
                Section("Quick note") {
                    HStack {
                        TextField("Type and press Add", text: $draft)
                        Button("Add") {
                            notes.append(Note(id: notes.count + 1, title: draft, body: "New note"))
                            draft = ""
                        }
                        .disabled(draft.isEmpty)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Notes")
        }
        .tint(.orange)
    }
}

struct NoteDetail: View {
    let note: Note

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(note.title).font(.largeTitle.bold())
                Text(note.body).font(.body)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        .navigationTitle(note.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview("Notes") {
    NotesView()
}
