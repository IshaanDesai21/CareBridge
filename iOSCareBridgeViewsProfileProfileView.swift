import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(.blue)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(authManager.currentUser?.fullName ?? "User")
                                .font(.title3)
                                .fontWeight(.bold)
                            
                            Text(authManager.currentUser?.email ?? "")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.leading, 8)
                    }
                    .padding(.vertical, 8)
                }
                
                Section("Health Information") {
                    NavigationLink {
                        Text("Medical History")
                    } label: {
                        Label("Medical History", systemImage: "doc.text")
                    }
                    
                    NavigationLink {
                        Text("Emergency Contacts")
                    } label: {
                        Label("Emergency Contacts", systemImage: "phone.fill")
                    }
                    
                    NavigationLink {
                        Text("Care Team")
                    } label: {
                        Label("Care Team", systemImage: "person.2.fill")
                    }
                }
                
                Section("Settings") {
                    NavigationLink {
                        Text("Accessibility")
                    } label: {
                        Label("Accessibility", systemImage: "accessibility")
                    }
                    
                    NavigationLink {
                        Text("Notifications")
                    } label: {
                        Label("Notifications", systemImage: "bell.fill")
                    }
                    
                    NavigationLink {
                        Text("Privacy")
                    } label: {
                        Label("Privacy", systemImage: "lock.fill")
                    }
                }
                
                Section {
                    Button(role: .destructive) {
                        authManager.logout()
                    } label: {
                        Label("Sign Out", systemImage: "arrow.right.square")
                    }
                }
            }
            .navigationTitle("Profile")
        }
    }
}

#Preview {
    ProfileView()
        .environmentObject(AuthenticationManager())
}
