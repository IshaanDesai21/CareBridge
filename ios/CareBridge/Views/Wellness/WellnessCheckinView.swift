import SwiftUI

struct WellnessCheckinView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authManager: AuthenticationManager
    
    @State private var energy = 5
    @State private var fatigue = 5
    @State private var pain = 5
    @State private var mood = 5
    @State private var sleepQuality = 5
    @State private var breathing = 5
    @State private var mobility = 5
    @State private var balance = 5
    @State private var speechClarity = 5
    @State private var appetite = 5
    @State private var hydration = 5
    @State private var swallowingDifficulty = 5
    @State private var notes = ""
    @State private var isSubmitting = false
    @State private var currentPage = 0
    
    let pages = 3
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Progress indicator
                ProgressView(value: Double(currentPage + 1), total: Double(pages))
                    .padding()
                
                TabView(selection: $currentPage) {
                    // Page 1: Energy & Pain
                    ScrollView {
                        VStack(spacing: 24) {
                            Text("How are you feeling today?")
                                .font(.title2)
                                .fontWeight(.bold)
                                .padding(.top)
                            
                            SliderRow(
                                label: "Energy Level",
                                value: $energy,
                                icon: "bolt.fill",
                                color: .yellow
                            )
                            
                            SliderRow(
                                label: "Fatigue",
                                value: $fatigue,
                                icon: "bed.double.fill",
                                color: .gray
                            )
                            
                            SliderRow(
                                label: "Pain Level",
                                value: $pain,
                                icon: "exclamationmark.triangle.fill",
                                color: .red
                            )
                            
                            SliderRow(
                                label: "Mood",
                                value: $mood,
                                icon: "face.smiling.fill",
                                color: .green
                            )
                            
                            SliderRow(
                                label: "Sleep Quality",
                                value: $sleepQuality,
                                icon: "moon.fill",
                                color: .purple
                            )
                        }
                        .padding()
                    }
                    .tag(0)
                    
                    // Page 2: Physical Function
                    ScrollView {
                        VStack(spacing: 24) {
                            Text("Physical Function")
                                .font(.title2)
                                .fontWeight(.bold)
                                .padding(.top)
                            
                            SliderRow(
                                label: "Breathing",
                                value: $breathing,
                                icon: "wind",
                                color: .blue
                            )
                            
                            SliderRow(
                                label: "Mobility",
                                value: $mobility,
                                icon: "figure.walk",
                                color: .orange
                            )
                            
                            SliderRow(
                                label: "Balance",
                                value: $balance,
                                icon: "figure.stand",
                                color: .teal
                            )
                            
                            SliderRow(
                                label: "Speech Clarity",
                                value: $speechClarity,
                                icon: "bubble.left.and.bubble.right.fill",
                                color: .indigo
                            )
                        }
                        .padding()
                    }
                    .tag(1)
                    
                    // Page 3: Nutrition & Notes
                    ScrollView {
                        VStack(spacing: 24) {
                            Text("Daily Habits")
                                .font(.title2)
                                .fontWeight(.bold)
                                .padding(.top)
                            
                            SliderRow(
                                label: "Appetite",
                                value: $appetite,
                                icon: "fork.knife",
                                color: .brown
                            )
                            
                            SliderRow(
                                label: "Hydration",
                                value: $hydration,
                                icon: "drop.fill",
                                color: .cyan
                            )
                            
                            SliderRow(
                                label: "Swallowing Difficulty",
                                value: $swallowingDifficulty,
                                icon: "pills.fill",
                                color: .pink
                            )
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Label("Additional Notes", systemImage: "note.text")
                                    .font(.headline)
                                
                                TextEditor(text: $notes)
                                    .frame(height: 120)
                                    .padding(8)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(8)
                            }
                        }
                        .padding()
                    }
                    .tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                
                // Navigation Buttons
                HStack(spacing: 16) {
                    if currentPage > 0 {
                        Button {
                            withAnimation {
                                currentPage -= 1
                            }
                        } label: {
                            Text("Previous")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color(.systemGray5))
                                .foregroundStyle(.primary)
                                .cornerRadius(12)
                        }
                    }
                    
                    Button {
                        if currentPage < pages - 1 {
                            withAnimation {
                                currentPage += 1
                            }
                        } else {
                            Task {
                                await submitCheckin()
                            }
                        }
                    } label: {
                        if isSubmitting {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding()
                        } else {
                            Text(currentPage < pages - 1 ? "Next" : "Submit")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundStyle(.white)
                                .cornerRadius(12)
                        }
                    }
                    .disabled(isSubmitting)
                }
                .padding()
            }
            .navigationTitle("Daily Check-in")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func submitCheckin() async {
        isSubmitting = true
        
        // Submit to API
        do {
            // Get patient ID from user (simplified for MVP)
            // In production, you'd fetch this from the patient profile
            let patientId = 1 // Placeholder
            
            guard let token = authManager.token else {
                print("No token available")
                isSubmitting = false
                return
            }
            
            let _ = try await APIService.shared.createWellnessCheckin(
                patientId: patientId,
                energy: energy,
                fatigue: fatigue,
                pain: pain,
                mood: mood,
                sleepQuality: sleepQuality,
                breathing: breathing,
                mobility: mobility,
                balance: balance,
                speechClarity: speechClarity,
                appetite: appetite,
                hydration: hydration,
                swallowingDifficulty: swallowingDifficulty,
                notes: notes.isEmpty ? nil : notes,
                token: token
            )
            
            dismiss()
        } catch {
            print("Error submitting check-in: \(error)")
        }
        
        isSubmitting = false
    }
}

struct SliderRow: View {
    let label: String
    @Binding var value: Int
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(label, systemImage: icon)
                    .font(.headline)
                    .foregroundStyle(color)
                
                Spacer()
                
                Text("\(value)")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(color)
                    .frame(width: 40)
            }
            
            Slider(value: Binding(
                get: { Double(value) },
                set: { value = Int($0) }
            ), in: 1...10, step: 1)
            .tint(color)
            
            HStack {
                Text("Low")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Text("High")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

#Preview {
    WellnessCheckinView()
        .environmentObject(AuthenticationManager())
}
