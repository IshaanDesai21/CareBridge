import SwiftUI

struct WellnessView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var showingCheckin = false
    @State private var wellnessHistory: [WellnessCheckin] = []
    @State private var isLoading = true
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Start Check-in Button
                    Button {
                        showingCheckin = true
                    } label: {
                        HStack {
                            Image(systemName: "heart.text.square.fill")
                                .font(.title2)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Daily Wellness Check-in")
                                    .font(.headline)
                                
                                Text("Track how you're feeling today")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                        }
                        .padding(20)
                        .background(Color.blue)
                        .foregroundStyle(.white)
                        .cornerRadius(16)
                    }
                    .padding(.horizontal)
                    .padding(.top)
                    
                    // History Section
                    if !wellnessHistory.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Recent Check-ins")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            ForEach(wellnessHistory.prefix(7)) { checkin in
                                WellnessHistoryCard(checkin: checkin)
                                    .padding(.horizontal)
                            }
                        }
                    } else if !isLoading {
                        VStack(spacing: 16) {
                            Image(systemName: "heart.slash")
                                .font(.system(size: 60))
                                .foregroundStyle(.secondary)
                            
                            Text("No check-ins yet")
                                .font(.headline)
                            
                            Text("Start your first daily wellness check-in to track your health over time")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        .padding(.vertical, 60)
                    }
                }
                .padding(.bottom, 32)
            }
            .navigationTitle("Wellness")
            .sheet(isPresented: $showingCheckin) {
                WellnessCheckinView()
            }
            .task {
                await loadHistory()
            }
        }
    }
    
    private func loadHistory() async {
        isLoading = true
        // Load from API
        isLoading = false
    }
}

struct WellnessHistoryCard: View {
    let checkin: WellnessCheckin
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(checkin.date)
                    .font(.headline)
                
                Spacer()
                
                if let mood = checkin.mood {
                    HStack(spacing: 4) {
                        Image(systemName: moodIcon(mood))
                            .foregroundStyle(moodColor(mood))
                        Text("\(mood)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            // Key metrics
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                MetricBadge(label: "Energy", value: checkin.energy ?? 0, color: .blue)
                MetricBadge(label: "Pain", value: checkin.pain ?? 0, color: .red)
                MetricBadge(label: "Sleep", value: checkin.sleepQuality ?? 0, color: .purple)
            }
            
            if let notes = checkin.notes, !notes.isEmpty {
                Text(notes)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    private func moodIcon(_ mood: Int) -> String {
        switch mood {
        case 8...10: return "face.smiling"
        case 5...7: return "face.dashed"
        default: return "face.frowning"
        }
    }
    
    private func moodColor(_ mood: Int) -> Color {
        switch mood {
        case 8...10: return .green
        case 5...7: return .orange
        default: return .red
        }
    }
}

struct MetricBadge: View {
    let label: String
    let value: Int
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(color)
            
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

#Preview {
    WellnessView()
        .environmentObject(AuthenticationManager())
}
