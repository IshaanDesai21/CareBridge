import SwiftUI

struct JournalView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var entries: [JournalEntry] = []
    @State private var isLoading = true
    @State private var showingNewEntry = false
    
    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                } else if entries.isEmpty {
                    EmptyStateView(
                        icon: "book",
                        title: "No Journal Entries",
                        description: "Start journaling to track your thoughts and feelings"
                    )
                } else {
                    List(entries) { entry in
                        JournalEntryRow(entry: entry)
                    }
                }
            }
            .navigationTitle("Journal")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingNewEntry = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingNewEntry) {
                NewJournalEntryView()
            }
            .task {
                await loadEntries()
            }
        }
    }
    
    private func loadEntries() async {
        isLoading = true
        // Load from API
        isLoading = false
    }
}

struct JournalEntryRow: View {
    let entry: JournalEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title = entry.title {
                Text(title)
                    .font(.headline)
            }
            
            if let content = entry.content {
                Text(content)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            
            HStack {
                if let mood = entry.mood {
                    Label(mood, systemImage: "face.smiling")
                        .font(.caption)
                }
                
                Spacer()
                
                Text(formattedDate(entry.createdAt))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func formattedDate(_ dateString: String) -> String {
        // Simple date formatting
        return dateString
    }
}

struct NewJournalEntryView: View {
    @Environment(\.dismiss) var dismiss
    @State private var title = ""
    @State private var content = ""
    @State private var mood = ""
    @State private var isSubmitting = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Title (optional)", text: $title)
                }
                
                Section {
                    TextEditor(text: $content)
                        .frame(minHeight: 200)
                }
                
                Section("How are you feeling?") {
                    Picker("Mood", selection: $mood) {
                        Text("Select mood").tag("")
                        Text("😊 Happy").tag("happy")
                        Text("😌 Calm").tag("calm")
                        Text("😔 Sad").tag("sad")
                        Text("😰 Anxious").tag("anxious")
                        Text("😤 Frustrated").tag("frustrated")
                    }
                }
            }
            .navigationTitle("New Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await saveEntry()
                        }
                    }
                    .disabled(content.isEmpty || isSubmitting)
                }
            }
        }
    }
    
    private func saveEntry() async {
        isSubmitting = true
        // Save to API
        dismiss()
    }
}

#Preview {
    JournalView()
        .environmentObject(AuthenticationManager())
}
