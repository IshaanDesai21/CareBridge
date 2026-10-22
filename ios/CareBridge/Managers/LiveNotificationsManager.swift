import Foundation

/// Maintains a WebSocket connection to the CareBridge backend so notifications
/// (e.g. a patient calling their caregiver) are delivered instantly while the
/// app is open, instead of only showing up next time the notifications list is
/// refreshed. Falls back gracefully — the in-app notification feed still works
/// via polling if the socket can't connect.
@MainActor
final class LiveNotificationsManager: NSObject, ObservableObject {
    static let shared = LiveNotificationsManager()

    @Published private(set) var isConnected = false
    /// Bumped whenever a live notification arrives, so views can refresh their list.
    @Published private(set) var lastReceivedAt: Date?
    /// Bumped on every successful socket auth (first connect and each reconnect), so views can
    /// re-fetch state that may have changed while the socket was down.
    @Published private(set) var authenticatedAt: Date?

    private var task: URLSessionWebSocketTask?
    private var session: URLSession?
    private var shouldReconnect = false
    private weak var authManager: AuthenticationManager?

    private override init() { super.init() }

    private var webSocketURL: URL? {
        let host = UserDefaults.standard.string(forKey: APIService.serverURLKey) ?? APIService.defaultServerURL
        guard var components = URLComponents(string: host) else { return nil }
        components.scheme = components.scheme == "https" ? "wss" : "ws"
        return components.url
    }

    func connect(authManager: AuthenticationManager) {
        guard let token = authManager.token, let url = webSocketURL else { return }
        self.authManager = authManager
        shouldReconnect = true

        let session = URLSession(configuration: .default, delegate: nil, delegateQueue: nil)
        self.session = session
        let task = session.webSocketTask(with: url)
        self.task = task
        task.resume()

        sendAuth(token: token)
        listen()
    }

    func disconnect() {
        shouldReconnect = false
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
        isConnected = false
    }

    private func sendAuth(token: String) {
        let payload: [String: String] = ["type": "auth", "token": token]
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let text = String(data: data, encoding: .utf8) else { return }
        task?.send(.string(text)) { _ in }
    }

    private func listen() {
        task?.receive { [weak self] result in
            // URLSessionWebSocketTask delivers this completion off the main actor;
            // hop back over before touching any MainActor-isolated state.
            Task { @MainActor in
                guard let self else { return }
                switch result {
                case .success(let message):
                    self.handle(message)
                    self.listen() // keep listening for the next message
                case .failure:
                    self.isConnected = false
                    self.reconnectAfterDelay()
                }
            }
        }
    }

    private func handle(_ message: URLSessionWebSocketTask.Message) {
        guard case .string(let text) = message,
              let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else { return }

        switch type {
        case "auth_ok":
            isConnected = true
            authenticatedAt = Date()
        case "notification":
            lastReceivedAt = Date()
            if let notif = json["notification"] as? [String: Any],
               let title = notif["title"] as? String,
               let body = notif["body"] as? String {
                NotificationsManager.shared.postLocal(title: title, body: body)
            }
        case "family_message":
            // In-app only (badge + conversation); deliberately no local system notification.
            // handle(_:) already runs on the main actor (see listen()).
            if let payload = json["message"],
               JSONSerialization.isValidJSONObject(payload),
               let messageData = try? JSONSerialization.data(withJSONObject: payload),
               let familyMessage = try? JSONDecoder().decode(FamilyMessage.self, from: messageData) {
                MessagesStore.shared.receive(familyMessage)
            }
        default:
            break
        }
    }

    private func reconnectAfterDelay() {
        guard shouldReconnect, let authManager else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            guard let self, self.shouldReconnect else { return }
            self.connect(authManager: authManager)
        }
    }
}
