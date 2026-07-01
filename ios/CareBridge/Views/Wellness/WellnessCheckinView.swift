import SwiftUI
import WidgetKit

struct WellnessCheckinView: View {
    var patientId: Int? = nil  // caregiver passes explicit ID; patient fetches their own

    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authManager: AuthenticationManager

    @State private var resolvedPatientId: Int? = nil
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
    @State private var weightKg = ""
    @State private var notes = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String? = nil
    @State private var currentPage = 0
    
    let pages = 3
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ProgressView(value: Double(currentPage + 1), total: Double(pages))
                    .tint(.cbPrimary)
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
                            
                            VStack(alignment: .leading, spacing: 10) {
                                Label("Weight (optional)", systemImage: "scalemass.fill")
                                    .font(.headline).foregroundStyle(Color.cbAmber)
                                HStack(spacing: 10) {
                                    TextField("e.g. 70.5", text: $weightKg)
                                        .keyboardType(.decimalPad)
                                        .padding(.horizontal, 14).padding(.vertical, 11)
                                        .background(Color.cbBackground)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                    Text("kg").font(.subheadline).foregroundStyle(.secondary)
                                }
                                Text("Tracks your weight trend over time")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            .padding()
                            .background(Color.white)
                            .cornerRadius(12)
                            .shadow(color: Color.cbBorder.opacity(0.6), radius: 5, x: 0, y: 2)

                            VStack(alignment: .leading, spacing: 8) {
                                Label("Additional Notes", systemImage: "note.text")
                                    .font(.headline)

                                TextEditor(text: $notes)
                                    .frame(height: 120)
                                    .padding(8)
                                    .background(Color.cbBackground)
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
                                .background(Color.cbBorder.opacity(0.5))
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
                                .background(Color.cbPrimary)
                                .foregroundStyle(.white)
                                .cornerRadius(12)
                        }
                    }
                    .disabled(isSubmitting)
                }
                .padding()
            }
            .background(Color.cbBackground.ignoresSafeArea())
            .navigationTitle("Daily Check-in")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .task {
            if let id = patientId {
                resolvedPatientId = id
            } else if let token = authManager.token {
                do {
                    resolvedPatientId = try await APIService.shared.getMyPatient(token: token)
                } catch {
                    errorMessage = "Failed to load patient profile."
                }
            }
        }
        .alert("Error", isPresented: .init(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK") { }
        } message: {
            if let errorMessage { Text(errorMessage) }
        }
    }
    
    @MainActor
    private func submitCheckin() async {
        guard let token = authManager.token, let pid = resolvedPatientId else {
            isSubmitting = false
            return
        }
        isSubmitting = true
        do {
            let finalNotes: String? = notes.isEmpty ? nil : notes
            let finalWeight: Double? = weightKg.isEmpty ? nil : Double(weightKg.replacingOccurrences(of: ",", with: "."))
            let _ = try await APIService.shared.createWellnessCheckin(
                patientId: pid,
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
                weight: finalWeight,
                notes: finalNotes,
                token: token
            )
            // Push data to home screen widget
            let sum1 = Double(energy) + Double(11 - fatigue) + Double(11 - pain)
            let sum2 = Double(mood) + Double(sleepQuality) + Double(breathing)
            let sum3 = Double(mobility) + Double(balance) + Double(speechClarity)
            let sum4 = Double(appetite) + Double(hydration) + Double(11 - swallowingDifficulty)
            let totalSum = sum1 + sum2 + sum3 + sum4
            let average = (totalSum / 12.0) * 10.0
            let wellnessScore = min(100, max(0, Int(average)))
            let suite = UserDefaults(suiteName: "group.com.carebridge.app")
            let fullName = [authManager.currentUser?.firstName, authManager.currentUser?.lastName].compactMap { $0 }.joined(separator: " ")
            suite?.set(fullName, forKey: "widget_patient_name")
            suite?.set(wellnessScore, forKey: "widget_wellness_score")
            suite?.set(energy, forKey: "widget_energy")
            suite?.set(mood, forKey: "widget_mood")
            let fmt = DateFormatter(); fmt.dateStyle = .short; fmt.timeStyle = .short
            suite?.set(fmt.string(from: Date()), forKey: "widget_last_checkin")
            WidgetCenter.shared.reloadAllTimelines()
            dismiss()
        } catch {
            print("Error submitting check-in: \(error)")
            errorMessage = "Failed to submit check-in. Please try again."
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
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.cbBorder.opacity(0.6), radius: 5, x: 0, y: 2)
    }
}

#Preview {
    WellnessCheckinView()
        .environmentObject(AuthenticationManager())
}
