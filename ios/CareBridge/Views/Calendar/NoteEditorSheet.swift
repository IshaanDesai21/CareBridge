import SwiftUI

/// Add or edit a note. `onSave` performs the write; errors are shown inline and keep the sheet open.
struct NoteEditorSheet: View {
    let title: String
    let onSave: (String) async throws -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var text: String
    @State private var saving = false
    @State private var errorMessage: String?

    init(title: String, initialText: String = "", onSave: @escaping (String) async throws -> Void) {
        self.title = title
        self.onSave = onSave
        _text = State(initialValue: initialText)
    }

    private var trimmed: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextEditor(text: $text)
                        .frame(minHeight: 160)
                        .accessibilityLabel("Note")
                }
                if let errorMessage {
                    Section {
                        Text(errorMessage).font(.subheadline).foregroundStyle(Color.cbRed)
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if saving {
                        ProgressView()
                    } else {
                        Button("Save") { Task { await save() } }
                            .disabled(trimmed.isEmpty)
                    }
                }
            }
            .interactiveDismissDisabled(saving)
        }
    }

    @MainActor private func save() async {
        saving = true
        errorMessage = nil
        do {
            try await onSave(trimmed)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        saving = false
    }
}
