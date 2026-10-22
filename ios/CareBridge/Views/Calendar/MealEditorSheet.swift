import SwiftUI

/// Add or edit a meal. `onSave(mealType, description)` performs the write; errors are shown inline.
struct MealEditorSheet: View {
    let title: String
    let onSave: (String, String) async throws -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var mealType: String
    @State private var text: String
    @State private var saving = false
    @State private var errorMessage: String?

    init(title: String, initialType: String? = nil, initialDescription: String = "",
         onSave: @escaping (String, String) async throws -> Void) {
        self.title = title
        self.onSave = onSave
        _mealType = State(initialValue: initialType ?? MealEditorSheet.defaultType())
        _text = State(initialValue: initialDescription)
    }

    /// Guess the meal from the time of day.
    private static func defaultType() -> String {
        switch Calendar.current.component(.hour, from: Date()) {
        case 4..<11: return "breakfast"
        case 11..<15: return "lunch"
        case 17..<22: return "dinner"
        default: return "snack"
        }
    }

    private var trimmed: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        NavigationStack {
            Form {
                Section("Meal") {
                    Picker("Meal", selection: $mealType) {
                        ForEach(Meal.types, id: \.self) { Text($0.capitalized).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }
                Section("What was eaten") {
                    TextField("e.g. Oatmeal with fruit", text: $text, axis: .vertical)
                        .lineLimit(3...8)
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
            try await onSave(mealType, trimmed)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        saving = false
    }
}
