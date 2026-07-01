import SwiftUI

struct HomeView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var todayCheckin: WellnessCheckin?
    @State private var showingHIPAAConsent = false
    @State private var hasAcceptedHIPAA = false
    @State private var showingCallCaregiverOptions = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Large Greeting
                Text("Hi, \(authManager.currentUser?.firstName ?? "there")!")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 40)
                
                Spacer()
                
                // Massive Action Buttons
                VStack(spacing: 24) {
                    
                    // Daily Check-in Button
                    Button(action: {
                        // Navigate to check-in or show check-in modal
                    }) {
                        HStack {
                            Image(systemName: todayCheckin != nil ? "checkmark.circle.fill" : "heart.text.square.fill")
                                .font(.system(size: 40))
                            Text(todayCheckin != nil ? "Check-in Done" : "Daily Check-in")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 32)
                        .background(todayCheckin != nil ? Color.green : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(24)
                        .shadow(color: (todayCheckin != nil ? Color.green : Color.blue).opacity(0.3), radius: 10, x: 0, y: 5)
                    }
                    
                    // Call Caregiver Button
                    Button(action: {
                        showingCallCaregiverOptions = true
                    }) {
                        HStack {
                            Image(systemName: "phone.circle.fill")
                                .font(.system(size: 40))
                            Text("Call Caregiver")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 32)
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(24)
                        .shadow(color: Color.orange.opacity(0.3), radius: 10, x: 0, y: 5)
                    }
                    .confirmationDialog("Call Caregiver", isPresented: $showingCallCaregiverOptions, titleVisibility: .visible) {
                        Button("Urgent Help Needed", role: .destructive) {
                            // Send urgent alert to caregiver dashboard
                            print("Urgent alert sent")
                        }
                        Button("Not Urgent - Just a Question") {
                            // Send normal notification
                            print("Non-urgent notification sent")
                        }
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        Text("Is this an emergency or a general question?")
                            .font(.title3)
                    }
                    
                    // Talk to AI Button (HIPAA locked)
                    Button(action: {
                        if !hasAcceptedHIPAA {
                            showingHIPAAConsent = true
                        } else {
                            // Open AI Companion
                        }
                    }) {
                        HStack {
                            Image(systemName: "message.circle.fill")
                                .font(.system(size: 40))
                            Text("Talk to AI")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 32)
                        .background(hasAcceptedHIPAA ? Color.purple : Color.gray.opacity(0.3))
                        .foregroundColor(hasAcceptedHIPAA ? .white : .secondary)
                        .cornerRadius(24)
                        .shadow(color: (hasAcceptedHIPAA ? Color.purple : Color.clear).opacity(0.3), radius: 10, x: 0, y: 5)
                    }
                    .sheet(isPresented: $showingHIPAAConsent) {
                        HIPAAConsentView(isAccepted: $hasAcceptedHIPAA)
                    }
                    
                }
                
                Spacer()
            }
            .padding(.horizontal, 24)
            .navigationBarHidden(true)
        }
    }
}

struct HIPAAConsentView: View {
    @Binding var isAccepted: Bool
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 32) {
            Text("Privacy Terms")
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .padding(.top, 40)
            
            ScrollView {
                Text("To use the AI Companion feature, we need your permission to securely analyze your health data.\n\nYour information is protected under HIPAA guidelines and is only used to provide personalized health insights and companionship.\n\nDo you consent to these terms?")
                    .font(.system(size: 24))
                    .multilineTextAlignment(.center)
                    .padding()
            }
            
            VStack(spacing: 16) {
                Button(action: {
                    isAccepted = true
                    dismiss()
                }) {
                    Text("I Agree")
                        .font(.system(size: 28, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(20)
                }
                
                Button(action: {
                    dismiss()
                }) {
                    Text("No Thanks")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(.vertical, 16)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 40)
        }
    }
}

#Preview {
    HomeView()
        .environmentObject(AuthenticationManager())
}
