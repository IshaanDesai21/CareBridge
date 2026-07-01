import SwiftUI
import WidgetKit

// MARK: - Home View

struct HomeView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var showCallDialog = false
    @State private var showAIChat = false
    @State private var alertSent = false
    @State private var sendingAlert = false
    @State private var alertError: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Hi, \(authManager.currentUser?.firstName ?? "there")")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(red: 0.1, green: 0.12, blue: 0.18))
                    Text("How are you feeling today?")
                        .font(.system(size: 17))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.top, 48)
                .padding(.bottom, 32)

                VStack(spacing: 16) {
                    NavigationLink(destination: WellnessCheckinView().environmentObject(authManager)) {
                        ActionButton(
                            title: "Daily Check-In",
                            subtitle: "Track how you're feeling",
                            icon: "heart.text.square.fill",
                            color: Color.cbPrimary
                        )
                    }

                    Button(action: { showCallDialog = true }) {
                        ActionButton(
                            title: alertSent ? "Caregiver Notified" : "Call Caregiver",
                            subtitle: alertSent ? "Your team has been alerted" : "Request help from your care team",
                            icon: alertSent ? "checkmark.circle.fill" : "phone.circle.fill",
                            color: alertSent ? Color.cbGreen : Color.cbAmber
                        )
                    }
                    .disabled(sendingAlert)

                    Button(action: { showAIChat = true }) {
                        ActionButton(
                            title: "Talk with AI",
                            subtitle: "Your companion is here",
                            icon: "bubble.left.and.bubble.right.fill",
                            color: Color.cbTeal
                        )
                    }
                }
                .padding(.horizontal, 24)

                if let err = alertError {
                    Text(err)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.top, 12)
                        .padding(.horizontal, 24)
                }

                Spacer()
            }
            .background(Color.cbBackground.ignoresSafeArea())
            .navigationBarHidden(true)
            .confirmationDialog("Contact your care team", isPresented: $showCallDialog, titleVisibility: .visible) {
                Button("Urgent — I need help now", role: .destructive) {
                    Task { await sendAlert(urgent: true, message: "URGENT: Patient needs immediate assistance") }
                }
                Button("Not urgent") {
                    Task { await sendAlert(urgent: false, message: "Patient would like to speak with their caregiver") }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Is this an emergency or a general question?")
            }
            .sheet(isPresented: $showAIChat) {
                AIChatView().environmentObject(authManager)
            }
        }
        .task { await syncWidgetData() }
    }

    @MainActor
    private func syncWidgetData() async {
        guard let token = authManager.token else { return }
        do {
            let pid = try await APIService.shared.getMyPatient(token: token)
            let history = try await APIService.shared.getWellnessHistory(patientId: pid, token: token)
            if let latest = history.first {
                let suite = UserDefaults(suiteName: "group.com.carebridge.app")
                let fullName = [authManager.currentUser?.firstName, authManager.currentUser?.lastName]
                    .compactMap { $0 }.joined(separator: " ")
                suite?.set(fullName, forKey: "widget_patient_name")
                // Recompute score from latest checkin metrics
                let e = latest.energy ?? 5, f = latest.fatigue ?? 5, p = latest.pain ?? 5
                let m = latest.mood ?? 5, s = latest.sleepQuality ?? 5, b = latest.breathing ?? 5
                let mo = latest.mobility ?? 5, ba = latest.balance ?? 5, sp = latest.speechClarity ?? 5
                let ap = latest.appetite ?? 5, hy = latest.hydration ?? 5, sw = latest.swallowingDifficulty ?? 5
                let total = Double(e) + Double(11-f) + Double(11-p) + Double(m) + Double(s) + Double(b)
                    + Double(mo) + Double(ba) + Double(sp) + Double(ap) + Double(hy) + Double(11-sw)
                let score = min(100, max(0, Int((total / 12.0) * 10.0)))
                suite?.set(score, forKey: "widget_wellness_score")
                suite?.set(e, forKey: "widget_energy")
                suite?.set(m, forKey: "widget_mood")
                let fmt = DateFormatter(); fmt.dateStyle = .short; fmt.timeStyle = .short
                suite?.set(fmt.string(from: Date()), forKey: "widget_last_checkin")
                WidgetCenter.shared.reloadAllTimelines()
            }
        } catch {}
    }

    @MainActor
    private func sendAlert(urgent: Bool, message: String) async {
        guard let token = authManager.token else { return }
        sendingAlert = true
        alertError = nil
        do {
            try await APIService.shared.sendAlert(message: message, isUrgent: urgent, token: token)
            alertSent = true
        } catch {
            alertError = "Could not reach server. Is the backend running at \(APIService.defaultServerURL)?"
        }
        sendingAlert = false
    }
}

// MARK: - Action Button

struct ActionButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 20) {
            Image(systemName: icon)
                .font(.system(size: 34))
                .foregroundStyle(.white)
                .frame(width: 58)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 21, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.8))
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white.opacity(0.6))
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 26)
        .background(color)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: color.opacity(0.35), radius: 10, x: 0, y: 5)
    }
}

// MARK: - AI Chat

struct ChatMessage: Identifiable {
    let id = UUID()
    let role: String
    let text: String
}

struct ChatBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.role == "user" { Spacer(minLength: 60) }
            Text(message.text)
                .font(.body)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(message.role == "user" ? Color.cbPrimary : Color.white)
                .foregroundStyle(message.role == "user" ? .white : .primary)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
            if message.role == "assistant" { Spacer(minLength: 60) }
        }
    }
}

struct AIChatView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authManager: AuthenticationManager

    @State private var companionName = "Alex"
    @State private var messages: [ChatMessage] = []
    @State private var inputText = ""
    @State private var isSending = false
    @State private var isLoadingCompanion = true

    var body: some View {
        NavigationStack {
            Group {
                if isLoadingCompanion {
                    VStack(spacing: 14) {
                        ProgressView()
                        Text("Connecting to \(companionName)…")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    VStack(spacing: 0) {
                        ScrollViewReader { proxy in
                            ScrollView {
                                LazyVStack(spacing: 12) {
                                    ForEach(messages) { msg in
                                        ChatBubble(message: msg)
                                            .id(msg.id)
                                    }
                                    if isSending {
                                        HStack(spacing: 8) {
                                            ProgressView().scaleEffect(0.75)
                                            Text("\(companionName) is thinking…")
                                                .font(.caption).foregroundStyle(.secondary)
                                            Spacer()
                                        }
                                        .padding(.horizontal, 16)
                                        .id("loading")
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                            }
                            .onChange(of: messages.count) { _, _ in
                                withAnimation { proxy.scrollTo(messages.last?.id) }
                            }
                            .onChange(of: isSending) { _, sending in
                                if sending { withAnimation { proxy.scrollTo("loading") } }
                            }
                        }

                        Divider()

                        HStack(spacing: 10) {
                            TextField("Say something…", text: $inputText, axis: .vertical)
                                .lineLimit(1...4)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(Color.cbBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 20))
                                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.cbBorder, lineWidth: 1))

                            Button { Task { await send() } } label: {
                                Image(systemName: "arrow.up.circle.fill")
                                    .font(.system(size: 34))
                                    .foregroundStyle(inputText.trimmingCharacters(in: .whitespaces).isEmpty || isSending
                                        ? Color.cbBorder : Color.cbPrimary)
                            }
                            .disabled(inputText.trimmingCharacters(in: .whitespaces).isEmpty || isSending)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.white)
                    }
                }
            }
            .background(Color.cbBackground.ignoresSafeArea())
            .navigationTitle(companionName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .task { await loadCompanion() }
    }

    @MainActor
    private func loadCompanion() async {
        guard let token = authManager.token else {
            setupGreeting(); isLoadingCompanion = false; return
        }
        do {
            let pid = try await APIService.shared.getMyPatient(token: token)
            let details = try await APIService.shared.getPatientDetails(patientId: pid, token: token)
            if let name = details.aiCompanionName, !name.isEmpty {
                companionName = name
            } else {
                let gender = details.gender?.lowercased()
                companionName = gender == "male" ? "James" : gender == "female" ? "Rose" : "Alex"
            }
        } catch {}
        setupGreeting()
        isLoadingCompanion = false
    }

    private func setupGreeting() {
        let firstName = authManager.currentUser?.firstName ?? "there"
        messages = [ChatMessage(role: "assistant", text: "Hi \(firstName)! I'm \(companionName). It's lovely to chat with you today — how are you feeling?")]
    }

    @MainActor
    private func send() async {
        guard let token = authManager.token else { return }
        let text = inputText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        inputText = ""
        messages.append(ChatMessage(role: "user", text: text))
        isSending = true
        do {
            let history: [[String: String]] = messages.dropLast().compactMap { msg in
                guard msg.role == "user" || msg.role == "assistant" else { return nil }
                return ["role": msg.role, "content": msg.text]
            }
            let response = try await APIService.shared.sendChatMessage(
                text,
                history: history,
                token: token
            )
            let replyText = response.reply
            if !response.companionName.isEmpty { companionName = response.companionName }
            messages.append(ChatMessage(role: "assistant", text: replyText))
        } catch {
            messages.append(ChatMessage(role: "assistant", text: "Sorry, I'm having trouble connecting right now. Try again in a moment!"))
        }
        isSending = false
    }
}

#Preview {
    HomeView().environmentObject(AuthenticationManager())
}
