import SwiftUI

// MARK: - Notification Bell (toolbar button with unread badge)

struct NotificationBellButton: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var accessibility: AccessibilityManager
    @ObservedObject private var live = LiveNotificationsManager.shared
    @State private var showSheet = false
    @State private var unreadCount = 0

    var body: some View {
        Button {
            accessibility.hapticImpact(.light)
            showSheet = true
        } label: {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "bell.fill")
                if unreadCount > 0 {
                    Text(unreadCount > 9 ? "9+" : "\(unreadCount)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(4)
                        .background(Color.cbRed)
                        .clipShape(Circle())
                        .offset(x: 10, y: -8)
                }
            }
        }
        .accessibilityLabel("Notifications")
        .accessibilityHint(accessibility.hint(unreadCount > 0 ? "\(unreadCount) unread notifications" : "No unread notifications"))
        .sheet(isPresented: $showSheet, onDismiss: { Task { await refreshCount() } }) {
            NotificationsListView()
                .environmentObject(authManager)
                .environmentObject(accessibility)
        }
        .task { await refreshCount() }
        .onChange(of: live.lastReceivedAt) { _, _ in Task { await refreshCount() } }
    }

    @MainActor
    private func refreshCount() async {
        guard let token = authManager.token else { return }
        let notifications = (try? await APIService.shared.getNotifications(token: token)) ?? []
        unreadCount = notifications.filter { $0.isRead == 0 }.count
    }
}

// MARK: - Notification List

struct NotificationsListView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var accessibility: AccessibilityManager
    @State private var notifications: [AppNotification] = []
    @State private var loading = true

    var body: some View {
        NavigationStack {
            Group {
                if loading {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if notifications.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "bell.slash")
                            .font(.system(size: 44)).foregroundStyle(.secondary)
                        Text("No notifications yet").foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(notifications) { notif in
                            Button {
                                Task { await markRead(notif) }
                            } label: {
                                HStack(alignment: .top, spacing: 12) {
                                    Circle()
                                        .fill(notif.isRead == 0 ? Color.cbPrimary : Color.clear)
                                        .frame(width: 8, height: 8)
                                        .padding(.top, 6)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(notif.title).font(.subheadline).fontWeight(.semibold)
                                            .foregroundStyle(.primary)
                                        Text(notif.body).font(.subheadline).foregroundStyle(.secondary)
                                        Text(relativeTime(notif.createdAt))
                                            .font(.caption2).foregroundStyle(.tertiary)
                                    }
                                }
                            }
                            .accessibilityHint(accessibility.hint(notif.isRead == 0 ? "Unread. Double tap to mark as read." : "Read"))
                        }
                    }
                    .refreshable { await load() }
                }
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .task { await load() }
    }

    @MainActor
    private func load() async {
        guard let token = authManager.token else { loading = false; return }
        notifications = (try? await APIService.shared.getNotifications(token: token)) ?? []
        loading = false
    }

    @MainActor
    private func markRead(_ notif: AppNotification) async {
        guard let token = authManager.token, notif.isRead == 0 else { return }
        accessibility.hapticImpact(.light)
        try? await APIService.shared.markNotificationRead(id: notif.id, token: token)
        if let idx = notifications.firstIndex(where: { $0.id == notif.id }) {
            notifications[idx] = AppNotification(
                id: notif.id, userId: notif.userId, title: notif.title,
                body: notif.body, type: notif.type, isRead: 1, createdAt: notif.createdAt
            )
        }
    }

    private func relativeTime(_ str: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        var date = formatter.date(from: str)
        if date == nil {
            let f = DateFormatter()
            f.dateFormat = "yyyy-MM-dd HH:mm:ss"
            f.timeZone = TimeZone(identifier: "UTC")
            date = f.date(from: str)
        }
        guard let date else { return str }
        let rel = RelativeDateTimeFormatter()
        rel.unitsStyle = .abbreviated
        return rel.localizedString(for: date, relativeTo: Date())
    }
}

#Preview {
    NotificationsListView()
        .environmentObject(AuthenticationManager())
        .environmentObject(AccessibilityManager.shared)
}
