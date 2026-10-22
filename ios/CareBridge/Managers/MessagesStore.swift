import Foundation

/// Shared state for the private patient↔family conversations: loaded messages and
/// unread counts per patient. Live `family_message` events arrive through
/// `LiveNotificationsManager` (already on the main actor) and land in `receive(_:)`.
@MainActor
final class MessagesStore: ObservableObject {
    static let shared = MessagesStore()

    /// Loaded messages per patient conversation, ascending by id.
    @Published var messages: [Int: [FamilyMessage]] = [:]
    /// Unread count per patient conversation.
    @Published var unread: [Int: Int] = [:]
    /// Whether older messages may exist beyond what is loaded, per conversation.
    @Published private(set) var hasOlder: [Int: Bool] = [:]
    @Published private(set) var loadingOlder: Set<Int> = []
    @Published var lastError: String?

    /// The conversation currently on screen; live messages for it don't count as unread.
    var openPatientId: Int?
    /// The signed-in user, so their own messages (echoed back over the socket) never count as unread.
    private(set) var currentUserId: Int?

    /// Matches the backend's default page size for GET /messages/:patientId.
    private let pageSize = 50
    private let api = APIService.shared

    private init() {}

    var totalUnread: Int { unread.values.reduce(0, +) }

    /// Binds the store to the signed-in user, dropping another account's cached conversations.
    func setCurrentUser(_ userId: Int?) {
        guard userId != currentUserId else { return }
        currentUserId = userId
        messages = [:]
        unread = [:]
        hasOlder = [:]
        loadingOlder = []
        openPatientId = nil
    }

    func load(patientId: Int, token: String) async {
        do {
            let page = try await api.getMessages(patientId: patientId, token: token)
            merge(page, into: patientId)
            if hasOlder[patientId] == nil { hasOlder[patientId] = page.count >= pageSize }
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    func loadOlder(patientId: Int, token: String) async {
        guard hasOlder[patientId] == true, !loadingOlder.contains(patientId),
              let oldest = messages[patientId]?.first?.id else { return }
        loadingOlder.insert(patientId)
        defer { loadingOlder.remove(patientId) }
        do {
            let page = try await api.getMessages(patientId: patientId, before: oldest, token: token)
            merge(page, into: patientId)
            hasOlder[patientId] = page.count >= pageSize
        } catch {
            lastError = error.localizedDescription
        }
    }

    func send(patientId: Int, content: String, token: String) async throws {
        let message = try await api.sendMessage(patientId: patientId, content: content, token: token)
        merge([message], into: patientId)
    }

    func markRead(patientId: Int, token: String) async {
        unread[patientId] = 0
        guard let lastId = messages[patientId]?.last?.id else { return }
        try? await api.markMessagesRead(patientId: patientId, lastReadMessageId: lastId, token: token)
    }

    func refreshUnread(token: String) async {
        guard let counts = try? await api.getUnreadCounts(token: token) else { return }
        var updated = counts
        // The open conversation is being read right now; don't flash a badge for it.
        if let open = openPatientId { updated[open] = 0 }
        unread = updated
    }

    /// A live message from the socket. Deduped by id; counts as unread only when its
    /// conversation isn't on screen and someone else sent it.
    func receive(_ message: FamilyMessage) {
        if messages[message.patientId]?.contains(where: { $0.id == message.id }) == true { return }
        merge([message], into: message.patientId)
        if message.patientId != openPatientId,
           message.senderUserId == nil || message.senderUserId != currentUserId {
            unread[message.patientId, default: 0] += 1
        }
    }

    private func merge(_ incoming: [FamilyMessage], into patientId: Int) {
        var byId = Dictionary((messages[patientId] ?? []).map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        for m in incoming { byId[m.id] = m }
        messages[patientId] = byId.values.sorted { $0.id < $1.id }
    }
}
