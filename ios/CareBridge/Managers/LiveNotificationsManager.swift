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

    private var task: URLSessionWebSocketTask?
    private var session: URLSession?
    private var shouldReconnect = false
    private weak var authManager: AuthenticationManager?
    private var reconnectWorkItem: DispatchWorkItem?

    /// Bumped on every connect()/disconnect(). A completion handler captures the
    /// epoch it was started under and checks it before touching shared state —
    /// this is what stops a stray callback from an already-abandoned connection
    /// from acting on (or racing with) a newer one.
    private var connectionEpoch = 0

    private override init() { super.init() }

    private var webSocketURL: URL? {
        let host = UserDefaults.standard.string(forKey: APIService.serverURLKey) ?? APIService.defaultServerURL
        guard var components = URLComponents(string: host) else { return nil }
        components.scheme = components.scheme == "https" ? "wss" : "ws"
        return components.url
    }

    func connect(authManager: AuthenticationManager) {
        guard let token = authManager.token, let url = webSocketURL else { return }
        // SwiftUI's onAppear can fire more than once (view re-appearing, app
        // returning from background) — never stack a second live socket on top
        // of one that's already up or connecting.
        guard task == nil else { return }

        self.authManager = authManager
        shouldReconnect = true
        connectionEpoch += 1
        let epoch = connectionEpoch

        // A real delegate (rather than nil) keeps the session's underlying
        // Mach-message plumbing bound to a stable object for its whole
        // lifetime — passing `delegate: nil` here is what let a previous
        // session's teardown race with a stray completion callback and abort
        // with "OS_dispatch_mach_msg _setContext:: unrecognized selector".
        let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        self.session = session
        let task = session.webSocketTask(with: url)
        self.task = task
        task.resume()

        sendAuth(token: token)
        listen(epoch: epoch)
    }

    func disconnect() {
        shouldReconnect = false
        reconnectWorkItem?.cancel()
        reconnectWorkItem = nil
        connectionEpoch += 1
        teardown()
        isConnected = false
    }

    /// Cancels and invalidates the current task/session so nothing is ever
    /// silently abandoned to ARC deallocation while a callback might still be
    /// in flight — that abandonment was the root cause of the crash.
    private func teardown() {
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
        session?.invalidateAndCancel()
        session = nil
    }

    private func sendAuth(token: String) {
        let payload: [String: String] = ["type": "auth", "token": token]
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let text = String(data: data, encoding: .utf8) else { return }
        task?.send(.string(text)) { _ in }
    }

    private func listen(epoch: Int) {
        task?.receive { [weak self] result in
            // URLSessionWebSocketTask delivers this completion off the main actor;
            // hop back over before touching any MainActor-isolated state.
            Task { @MainActor in
                guard let self, self.connectionEpoch == epoch else { return } // stale callback from a superseded connection
                switch result {
                case .success(let message):
                    self.handle(message)
                    self.listen(epoch: epoch) // keep listening for the next message
                case .failure:
                    self.isConnected = false
                    self.connectionEpoch += 1 // this connection is dead — invalidate its callbacks too
                    self.teardown()
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
        case "notification":
            lastReceivedAt = Date()
            if let notif = json["notification"] as? [String: Any],
               let title = notif["title"] as? String,
               let body = notif["body"] as? String {
                NotificationsManager.shared.postLocal(title: title, body: body)
            }
        default:
            break
        }
    }

    private func reconnectAfterDelay() {
        guard shouldReconnect, let authManager else { return }
        reconnectWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self, self.shouldReconnect else { return }
            self.connect(authManager: authManager)
        }
        reconnectWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: workItem)
    }
}

// A concrete (if empty) URLSessionDelegate — see the comment in connect().
extension LiveNotificationsManager: URLSessionDelegate {}
