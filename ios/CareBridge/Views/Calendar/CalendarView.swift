import SwiftUI

/// Month grid + the selected day's cards for one patient. Expects to be inside a NavigationStack.
struct CalendarView: View {
    let patientId: Int
    /// "patient", "caregiver", "organization" or "family".
    let viewerRole: String

    @EnvironmentObject var authManager: AuthenticationManager

    @State private var displayedMonth = Date()
    @State private var selectedDate = Date().localDateString
    @State private var summaries: [String: CalendarDaySummary] = [:]
    @State private var day: CalendarDay?
    @State private var loadingDay = false
    @State private var errorMessage: String?
    @State private var noteEditor: NoteEditing?
    @State private var mealEditor: MealEditing?

    private struct NoteEditing: Identifiable {
        let id = UUID()
        let note: DayNote?
    }

    private struct MealEditing: Identifiable {
        let id = UUID()
        let meal: Meal?
    }

    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone.autoupdatingCurrent
        return c
    }

    /// Family members are read-only; everyone else can add meals and notes.
    private var canWrite: Bool { viewerRole != "family" }

    private var monthKey: String {
        let c = calendar.dateComponents([.year, .month], from: displayedMonth)
        return String(format: "%04d-%02d", c.year ?? 0, c.month ?? 0)
    }

    private var monthTitle: String {
        displayedMonth.formatted(.dateTime.month(.wide).year())
    }

    private var selectedDateTitle: String {
        guard let date = Date.fromLocalDateString(selectedDate) else { return selectedDate }
        if selectedDate == Date().localDateString { return "Today" }
        return date.formatted(.dateTime.weekday(.wide).month(.wide).day())
    }

    var body: some View {
        List {
            if let errorMessage {
                Section {
                    HStack(alignment: .top) {
                        Image(systemName: "exclamationmark.circle.fill")
                        Text(errorMessage).font(.subheadline)
                        Spacer()
                        Button {
                            self.errorMessage = nil
                        } label: {
                            Image(systemName: "xmark").font(.caption)
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel("Dismiss error")
                    }
                    .foregroundStyle(Color.cbRed)
                    .listRowBackground(Color.cbRed.opacity(0.08))
                }
            }

            Section {
                monthHeader
                    .listRowSeparator(.hidden)
                CalendarMonthGrid(monthStart: displayedMonth, summaries: summaries, selectedDate: $selectedDate)
                    .padding(.vertical, 4)
            }

            Section {
                EmptyView()
            } header: {
                HStack {
                    Text(selectedDateTitle).font(.headline).foregroundStyle(.primary).textCase(nil)
                    if loadingDay { ProgressView().padding(.leading, 4) }
                }
            }

            if let day, day.date == selectedDate {
                CalendarDayCards(
                    day: day,
                    currentUserId: authManager.currentUser?.id,
                    canWrite: canWrite,
                    onEditMeal: { mealEditor = MealEditing(meal: $0) },
                    onDeleteMeal: { meal in Task { await perform { try await deleteMeal(meal) } } },
                    onEditNote: { noteEditor = NoteEditing(note: $0) },
                    onDeleteNote: { note in Task { await perform { try await deleteNote(note) } } }
                )
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Calendar")
        .toolbar {
            if canWrite {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button { noteEditor = NoteEditing(note: nil) } label: {
                            Label("Add note", systemImage: "note.text.badge.plus")
                        }
                        Button { mealEditor = MealEditing(meal: nil) } label: {
                            Label("Add meal", systemImage: "fork.knife")
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add")
                }
            }
        }
        .refreshable { await reloadAll() }
        .task(id: monthKey) { await loadMonth() }
        .task(id: selectedDate) { await loadDay() }
        .sheet(item: $noteEditor) { editing in
            NoteEditorSheet(title: editing.note == nil ? "Add note" : "Edit note",
                            initialText: editing.note?.content ?? "") { content in
                try await saveNote(editing.note, content: content)
                await reloadAll()
            }
        }
        .sheet(item: $mealEditor) { editing in
            MealEditorSheet(title: editing.meal == nil ? "Add meal" : "Edit meal",
                            initialType: editing.meal?.mealType,
                            initialDescription: editing.meal?.description ?? "") { type, description in
                try await saveMeal(editing.meal, mealType: type, description: description)
                await reloadAll()
            }
        }
    }

    private var monthHeader: some View {
        HStack {
            Button { shiftMonth(-1) } label: {
                Image(systemName: "chevron.left").padding(8)
            }
            .accessibilityLabel("Previous month")
            Spacer()
            Text(monthTitle).font(.headline)
            Spacer()
            Button { shiftMonth(1) } label: {
                Image(systemName: "chevron.right").padding(8)
            }
            .accessibilityLabel("Next month")
        }
        .buttonStyle(.borderless)
        .foregroundStyle(Color.cbPrimary)
    }

    private func shiftMonth(_ delta: Int) {
        if let next = calendar.date(byAdding: .month, value: delta, to: displayedMonth) {
            displayedMonth = next
        }
    }

    // MARK: Loading

    private var token: String { authManager.token ?? "" }

    @MainActor private func loadMonth() async {
        let key = monthKey
        do {
            let month = try await APIService.shared.getCalendarMonth(patientId: patientId, month: key, token: token)
            guard key == monthKey else { return }
            summaries = Dictionary(month.days.map { ($0.date, $0) }, uniquingKeysWith: { _, last in last })
        } catch {
            if !Task.isCancelled { errorMessage = error.localizedDescription }
        }
    }

    @MainActor private func loadDay() async {
        let date = selectedDate
        loadingDay = true
        defer { if date == selectedDate { loadingDay = false } }
        do {
            let loaded = try await APIService.shared.getCalendarDay(patientId: patientId, date: date, token: token)
            guard date == selectedDate else { return }
            day = loaded
        } catch {
            if !Task.isCancelled { errorMessage = error.localizedDescription }
        }
    }

    @MainActor private func reloadAll() async {
        await loadDay()
        await loadMonth()
    }

    // MARK: Writes (each followed by a day + month re-fetch)

    @MainActor private func perform(_ write: () async throws -> Void) async {
        do {
            try await write()
            errorMessage = nil
            await reloadAll()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func saveNote(_ existing: DayNote?, content: String) async throws {
        if let existing {
            try await APIService.shared.updateNote(kind: existing.kind, id: existing.id, content: content, token: token)
        } else if viewerRole == "patient" {
            try await APIService.shared.addPatientNote(patientId: patientId, content: content,
                                                       localDate: selectedDate, token: token)
        } else {
            try await APIService.shared.addCareNote(patientId: patientId, content: content,
                                                    localDate: selectedDate, token: token)
        }
    }

    private func saveMeal(_ existing: Meal?, mealType: String, description: String) async throws {
        if let existing {
            try await APIService.shared.updateMeal(id: existing.id, mealType: mealType,
                                                   description: description, token: token)
        } else {
            try await APIService.shared.addMeal(patientId: patientId, mealType: mealType, description: description,
                                                localDate: selectedDate, token: token)
        }
    }

    private func deleteMeal(_ meal: Meal) async throws {
        try await APIService.shared.deleteMeal(id: meal.id, token: token)
    }

    private func deleteNote(_ note: DayNote) async throws {
        try await APIService.shared.deleteNote(kind: note.kind, id: note.id, token: token)
    }
}

/// Patient's own Calendar tab: resolves the patient id, then shows `CalendarView`.
struct PatientCalendarTab: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var patientId: Int?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if let patientId {
                    CalendarView(patientId: patientId, viewerRole: "patient")
                } else if let errorMessage {
                    ContentUnavailableView {
                        Label("Couldn't load your calendar", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(errorMessage)
                    } actions: {
                        Button("Try again") { Task { await load() } }
                    }
                } else {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .background(Color.cbBackground.ignoresSafeArea())
        }
        .task { if patientId == nil { await load() } }
    }

    @MainActor private func load() async {
        guard let token = authManager.token else { return }
        do {
            patientId = try await APIService.shared.getMyPatient(token: token)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
