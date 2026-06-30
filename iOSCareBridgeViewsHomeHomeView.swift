import SwiftUI

struct HomeView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var wellnessScore = 75
    @State private var todayCheckin: WellnessCheckin?
    @State private var upcomingAppointments: [Appointment] = []
    @State private var isLoading = true
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Welcome Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Welcome back,")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                        
                        Text(authManager.currentUser?.fullName ?? "Patient")
                            .font(.system(size: 34, weight: .bold))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.top)
                    
                    // Wellness Score Card
                    WellnessScoreCard(score: wellnessScore)
                        .padding(.horizontal)
                    
                    // Daily Check-in Status
                    CheckinStatusCard(completed: todayCheckin != nil)
                        .padding(.horizontal)
                    
                    // Quick Actions
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Quick Actions")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 16) {
                            QuickActionButton(
                                icon: "heart.text.square.fill",
                                title: "Daily Check-in",
                                color: .blue
                            )
                            
                            QuickActionButton(
                                icon: "pill.fill",
                                title: "Medications",
                                color: .green
                            )
                            
                            QuickActionButton(
                                icon: "calendar",
                                title: "Appointments",
                                color: .orange
                            )
                            
                            QuickActionButton(
                                icon: "message.fill",
                                title: "AI Companion",
                                color: .purple
                            )
                        }
                        .padding(.horizontal)
                    }
                    
                    // Upcoming Appointments
                    if !upcomingAppointments.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Upcoming Appointments")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            ForEach(upcomingAppointments.prefix(3)) { appointment in
                                AppointmentCard(appointment: appointment)
                                    .padding(.horizontal)
                            }
                        }
                    }
                }
                .padding(.bottom, 32)
            }
            .navigationTitle("CareBridge")
            .navigationBarTitleDisplayMode(.inline)
            .refreshable {
                await loadData()
            }
        }
        .task {
            await loadData()
        }
    }
    
    private func loadData() async {
        isLoading = true
        // Load data from API
        // For now, using mock data
        isLoading = false
    }
}

struct WellnessScoreCard: View {
    let score: Int
    
    var scoreColor: Color {
        switch score {
        case 80...100: return .green
        case 60..<80: return .orange
        default: return .red
        }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Wellness Score")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    
                    Text("\(score)")
                        .font(.system(size: 56, weight: .bold))
                        .foregroundStyle(scoreColor)
                }
                
                Spacer()
                
                ZStack {
                    Circle()
                        .stroke(scoreColor.opacity(0.2), lineWidth: 12)
                        .frame(width: 100, height: 100)
                    
                    Circle()
                        .trim(from: 0, to: CGFloat(score) / 100)
                        .stroke(scoreColor, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                        .frame(width: 100, height: 100)
                        .rotationEffect(.degrees(-90))
                        .animation(.spring(), value: score)
                }
            }
            
            Text("Your overall health is looking good. Keep up the great work!")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(24)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
    }
}

struct CheckinStatusCard: View {
    let completed: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: completed ? "checkmark.circle.fill" : "clock.fill")
                .font(.system(size: 40))
                .foregroundStyle(completed ? .green : .orange)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(completed ? "Check-in Complete" : "Daily Check-in")
                    .font(.headline)
                
                Text(completed ? "Great job today!" : "Take a moment to log how you're feeling")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            if !completed {
                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .background(completed ? Color.green.opacity(0.1) : Color.orange.opacity(0.1))
        .cornerRadius(12)
    }
}

struct QuickActionButton: View {
    let icon: String
    let title: String
    let color: Color
    
    var body: some View {
        Button {
            // Action
        } label: {
            VStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 32))
                    .foregroundStyle(color)
                
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
        }
    }
}

struct AppointmentCard: View {
    let appointment: Appointment
    
    var body: some View {
        HStack(spacing: 16) {
            VStack {
                Text("15")
                    .font(.title2)
                    .fontWeight(.bold)
                Text("DEC")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 60)
            .padding(.vertical, 8)
            .background(Color.blue.opacity(0.1))
            .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(appointment.title)
                    .font(.headline)
                
                if let provider = appointment.providerName {
                    Text(provider)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Text("2:00 PM")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

#Preview {
    HomeView()
        .environmentObject(AuthenticationManager())
}
