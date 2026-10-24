import SwiftUI

/// Messages tab for patients and family members (never caregivers/organizations).
/// A patient goes straight to their own family conversation; a family member with one
/// linked patient does too, and with several picks a conversation from a list.
struct MessagesView: View {
    let role: String

    @EnvironmentObject var authManager: AuthenticationManager
    @ObservedObject private var store = MessagesStore.shared

    @State private var patientId: Int?
    @State private var patients: [Patient] = []
    @State private var loading = true
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if loading {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let errorMessage {
                    ContentUnavailableView {
                        Label("Couldn't load messages", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(errorMessage)
                    } actions: {
                        Button("Try again") { Task { await load() } }
                    }
                } else if role == "patient" {
                    if let patientId {
                        ConversationView(patientId: patientId, title: "Family")
                    }
                } else if patients.count == 1, let only = patients.first {
                    ConversationView(patientId: only.id, title: Self.name(of: only))
                } else if patients.isEmpty {
                    ContentUnavailableView("No conversations", systemImage: "bubble.left.and.bubble.right",
                                           description: Text("Link to a patient to message them and their family."))
                } else {
                    List(patients) { patient in
                        NavigationLink {
                            ConversationView(patientId: patient.id, title: Self.name(of: patient))
                        } label: {
                            row(for: patient)
                        }
                    }
                    .listStyle(.insetGrouped)
                    .navigationTitle("Messages")
                    .refreshable { await load() }
                }
            }
            .background(Color.cbBackground.ignoresSafeArea())
        }
        .task { if loading { await load() } }
    }

    private func row(for patient: Patient) -> some View {
        let count = store.unread[patient.id] ?? 0
        return HStack(spacing: 12) {
            Image(systemName: "person.crop.circle.fill")
                .font(.title2)
                .foregroundStyle(Color.cbPrimary)
            Text(Self.name(of: patient))
                .font(.body.weight(count > 0 ? .semibold : .regular))
            Spacer()
            if count > 0 {
                Text("\(count)")
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.cbRed))
                    .accessibilityLabel("\(count) unread")
            }
        }
        .padding(.vertical, 4)
    }

    static func name(of patient: Patient) -> String {
        let name = [patient.firstName, patient.lastName].compactMap { $0 }.joined(separator: " ")
        return name.isEmpty ? "Patient" : name
    }

    @MainActor private func load() async {
        guard let token = authManager.token else { return }
        do {
            if role == "patient" {
                patientId = try await APIService.shared.getMyPatient(token: token)
            } else {
                patients = try await APIService.shared.getLinkedPatients(token: token)
                await store.refreshUnread(token: token)
            }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
        loading = false
    }
}
