import SwiftUI

/// The selected day's cards, as List sections: Check-in, Medications, Flagged
/// (only when non-empty), Meals, Notes. Edit/delete swipe actions appear only
/// on entries the current user authored.
struct CalendarDayCards: View {
    let day: CalendarDay
    let currentUserId: Int?
    let canWrite: Bool
    var onEditMeal: (Meal) -> Void = { _ in }
    var onDeleteMeal: (Meal) -> Void = { _ in }
    var onEditNote: (DayNote) -> Void = { _ in }
    var onDeleteNote: (DayNote) -> Void = { _ in }

    var body: some View {
        Group {
            checkinSection
            medicationsSection
            if !day.flags.isEmpty { flaggedSection }
            mealsSection
            notesSection
        }
    }

    private func isOwn(_ authorUserId: Int?) -> Bool {
        canWrite && authorUserId != nil && authorUserId == currentUserId
    }

    // MARK: Check-in

    private var checkinSection: some View {
        Section {
            if let c = day.checkin {
                CheckinCard(checkin: c)
            } else {
                emptyText("No check-in")
            }
        } header: {
            cardHeader("Check-in", systemImage: "heart.text.square")
        }
    }

    // MARK: Medications

    private var medicationsSection: some View {
        Section {
            ForEach(day.progress) { p in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(medName(p.name, p.strength)).font(.subheadline).fontWeight(.semibold)
                        if p.asNeeded {
                            Text("As needed").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Text(p.label)
                        .font(.caption).fontWeight(.medium)
                        .foregroundStyle(!p.asNeeded && p.given >= p.dosesPerDay ? Color.cbGreen : Color.secondary)
                }
            }
            if day.doses.isEmpty {
                emptyText("No doses logged")
            } else {
                ForEach(day.doses) { dose in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.cbGreen)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(medName(dose.name ?? "Medication", dose.strength) + (dose.pillCount > 1 ? " × \(dose.pillCount)" : ""))
                                .font(.subheadline)
                            if dose.isManual {
                                Text("logged manually").font(.caption).foregroundStyle(.secondary)
                            }
                            if !dose.strengthVerified {
                                Text("strength not verified").font(.caption).foregroundStyle(Color.cbAmber)
                            }
                        }
                        Spacer()
                        if let time = CalendarTimestamp.time(dose.givenAt) {
                            Text(time).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        } header: {
            cardHeader("Medications", systemImage: "pill")
        }
    }

    // MARK: Flagged

    private var flaggedSection: some View {
        Section {
            ForEach(day.flags) { flag in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                        Text("Pill check failed").fontWeight(.semibold)
                        Spacer()
                        if let time = CalendarTimestamp.time(flag.createdAt) {
                            Text(time).font(.caption)
                        }
                    }
                    .font(.subheadline)
                    .foregroundStyle(Color.cbRed)
                    ForEach(Array(flag.messages.enumerated()), id: \.offset) { _, message in
                        Text("• " + message).font(.caption).foregroundStyle(.primary)
                    }
                }
                .padding(.vertical, 2)
                .listRowBackground(Color.cbRed.opacity(0.08))
            }
        } header: {
            cardHeader("Flagged", systemImage: "flag.fill", tint: Color.cbRed)
        }
    }

    // MARK: Meals

    private var mealsSection: some View {
        Section {
            if day.meals.isEmpty {
                emptyText("No meals logged")
            } else {
                ForEach(day.meals) { meal in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(meal.mealType.capitalized).font(.subheadline).fontWeight(.semibold)
                        Text(meal.description).font(.subheadline)
                        byline(meal.authorName, meal.createdAt)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        if isOwn(meal.authorUserId) {
                            Button(role: .destructive) { onDeleteMeal(meal) } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            Button { onEditMeal(meal) } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            .tint(Color.cbPrimary)
                        }
                    }
                }
            }
        } header: {
            cardHeader("Meals", systemImage: "fork.knife")
        }
    }

    // MARK: Notes

    private var notesSection: some View {
        Section {
            if day.notes.isEmpty {
                emptyText("No notes")
            } else {
                ForEach(day.notes, id: \.uid) { note in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text(note.authorName ?? "Unknown").font(.subheadline).fontWeight(.semibold)
                            kindBadge(note)
                            Spacer()
                            if let time = CalendarTimestamp.time(note.createdAt) {
                                Text(time).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        Text(note.content).font(.subheadline)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        if isOwn(note.authorUserId) {
                            // Care notes have no backend DELETE, so only patient notes are deletable.
                            if !note.isCaregiverNote {
                                Button(role: .destructive) { onDeleteNote(note) } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            Button { onEditNote(note) } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            .tint(Color.cbPrimary)
                        }
                    }
                }
            }
        } header: {
            cardHeader("Notes", systemImage: "note.text")
        }
    }

    // MARK: Pieces

    private func cardHeader(_ title: String, systemImage: String, tint: Color = .secondary) -> some View {
        Label(title, systemImage: systemImage).foregroundStyle(tint)
    }

    private func emptyText(_ text: String) -> some View {
        Text(text).font(.subheadline).foregroundStyle(.secondary)
    }

    private func medName(_ name: String, _ strength: String?) -> String {
        [name, strength].compactMap { $0 }.joined(separator: " ")
    }

    private func byline(_ author: String?, _ createdAt: String?) -> some View {
        Text([author, CalendarTimestamp.time(createdAt)].compactMap { $0 }.joined(separator: " · "))
            .font(.caption).foregroundStyle(.secondary)
    }

    private func kindBadge(_ note: DayNote) -> some View {
        let color = note.isCaregiverNote ? Color.cbTeal : Color.cbPrimary
        return Text(note.isCaregiverNote ? "Caregiver" : "Patient")
            .font(.caption2).fontWeight(.semibold)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(color.opacity(0.12))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}

/// Mood, energy, pain and sleep up front; the remaining metrics behind a "+N more" disclosure.
private struct CheckinCard: View {
    let checkin: DayCheckin
    @State private var expanded = false

    private var primary: [(String, Int?)] {
        [("Mood", checkin.mood), ("Energy", checkin.energy), ("Pain", checkin.pain), ("Sleep", checkin.sleepQuality)]
    }

    private var more: [(String, Int)] {
        let all: [(String, Int?)] = [
            ("Fatigue", checkin.fatigue), ("Breathing", checkin.breathing), ("Mobility", checkin.mobility),
            ("Balance", checkin.balance), ("Speech clarity", checkin.speechClarity), ("Appetite", checkin.appetite),
            ("Hydration", checkin.hydration), ("Swallowing difficulty", checkin.swallowingDifficulty),
        ]
        return all.compactMap { name, value in value.map { (name, $0) } }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                ForEach(primary, id: \.0) { name, value in
                    VStack(spacing: 2) {
                        Text(value.map(String.init) ?? "–")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.cbPrimary)
                        Text(name).font(.caption2).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            if let notes = checkin.notes, !notes.isEmpty {
                Text(notes).font(.caption).foregroundStyle(.secondary)
            }
            if !more.isEmpty {
                DisclosureGroup(isExpanded: $expanded) {
                    ForEach(more, id: \.0) { name, value in
                        HStack {
                            Text(name).font(.subheadline)
                            Spacer()
                            Text("\(value)/10").font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                } label: {
                    Text(expanded ? "Show less" : "+\(more.count) more")
                        .font(.subheadline).foregroundStyle(Color.cbPrimary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
