import SwiftUI

/// One patient's private family conversation: bubbles, paging back through history
/// (pull down or scroll to the top), and a composer. While on screen it is the store's
/// open conversation, so live messages for it are marked read instead of badged.
struct ConversationView: View {
    let patientId: Int
    var title: String = "Family"

    @EnvironmentObject var authManager: AuthenticationManager
    @ObservedObject private var store = MessagesStore.shared

    @State private var draft = ""
    @State private var sending = false
    @State private var sendError: String?
    @State private var loaded = false
    @FocusState private var composerFocused: Bool

    private var messages: [FamilyMessage] { store.messages[patientId] ?? [] }
    private var canSend: Bool { !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !sending }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 10) {
                    if store.hasOlder[patientId] == true {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .onAppear { Task { await loadOlder(proxy: proxy) } }
                    }
                    if loaded && messages.isEmpty {
                        Text("No messages yet. Say hello!")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.top, 40)
                    }
                    ForEach(messages) { message in
                        MessageBubble(message: message, isMine: isMine(message))
                            .id(message.id)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
            }
            .defaultScrollAnchor(.bottom)
            .scrollDismissesKeyboard(.interactively)
            .refreshable { await loadOlder(proxy: proxy) }
            .onChange(of: messages.last?.id) { _, lastId in
                guard let lastId else { return }
                withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo(lastId, anchor: .bottom) }
                if store.openPatientId == patientId { Task { await markRead() } }
            }
        }
        .background(Color.cbBackground.ignoresSafeArea())
        .safeAreaInset(edge: .bottom) { composer }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 1) {
                    Text(title).font(.headline)
                    Text("Only you and family can see these messages.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
            }
        }
        .onAppear {
            store.openPatientId = patientId
            Task {
                await load()
                await markRead()
            }
        }
        .onDisappear {
            if store.openPatientId == patientId { store.openPatientId = nil }
        }
    }

    private var composer: some View {
        VStack(spacing: 4) {
            if let sendError {
                Text(sendError)
                    .font(.caption)
                    .foregroundStyle(Color.cbRed)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            HStack(alignment: .bottom, spacing: 8) {
                TextField("Message", text: $draft, axis: .vertical)
                    .lineLimit(1...5)
                    .focused($composerFocused)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(RoundedRectangle(cornerRadius: 20).fill(Color.white))
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.cbBorder))
                Button {
                    Task { await send() }
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 34))
                        .foregroundStyle(canSend ? Color.cbPrimary : Color.gray.opacity(0.4))
                }
                .disabled(!canSend)
                .accessibilityLabel("Send")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.bar)
    }

    private func isMine(_ message: FamilyMessage) -> Bool {
        guard let me = authManager.currentUser?.id, let sender = message.senderUserId else { return false }
        return me == sender
    }

    private func load() async {
        guard let token = authManager.token else { return }
        await store.load(patientId: patientId, token: token)
        loaded = true
    }

    private func loadOlder(proxy: ScrollViewProxy) async {
        guard let token = authManager.token else { return }
        let anchor = messages.first?.id
        await store.loadOlder(patientId: patientId, token: token)
        // Keep the previously-oldest message in view instead of jumping to the new top.
        if let anchor, messages.first?.id != anchor { proxy.scrollTo(anchor, anchor: .top) }
    }

    private func markRead() async {
        guard let token = authManager.token else { return }
        await store.markRead(patientId: patientId, token: token)
    }

    private func send() async {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, let token = authManager.token else { return }
        sending = true
        defer { sending = false }
        do {
            try await store.send(patientId: patientId, content: text, token: token)
            draft = ""
            sendError = nil
        } catch {
            sendError = "Couldn't send: \(error.localizedDescription)"
        }
    }
}

private struct MessageBubble: View {
    let message: FamilyMessage
    let isMine: Bool

    var body: some View {
        HStack {
            if isMine { Spacer(minLength: 48) }
            VStack(alignment: isMine ? .trailing : .leading, spacing: 3) {
                if !isMine {
                    Text(message.senderName.isEmpty ? "Former member" : message.senderName)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)
                }
                Text(message.content)
                    .font(.body)
                    .foregroundStyle(isMine ? .white : .primary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(isMine ? Color.cbPrimary : Color.white)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(isMine ? Color.clear : Color.cbBorder)
                    )
                if let date = message.createdDate {
                    Text(Self.timestamp(date))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)
                }
            }
            if !isMine { Spacer(minLength: 48) }
        }
        .accessibilityElement(children: .combine)
    }

    private static func timestamp(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) {
            return date.formatted(date: .omitted, time: .shortened)
        }
        return date.formatted(.dateTime.month(.abbreviated).day().hour().minute())
    }
}
