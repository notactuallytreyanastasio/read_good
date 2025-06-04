import SwiftUI

struct RedditCredentialsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var credentialManager = CredentialManager.shared
    
    @State private var clientId = ""
    @State private var clientSecret = ""
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var showingHelp = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Compact header
            VStack(spacing: 6) {
                HStack {
                    Image(systemName: "globe")
                        .font(.system(size: 12))
                        .foregroundColor(.orange)
                    
                    Text("Reddit Setup")
                        .font(.system(size: 11, weight: .medium))
                    
                    Spacer()
                    
                    Button(action: { showingHelp = true }) {
                        Image(systemName: "questionmark.circle")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                Text("Enter Reddit API credentials")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(NSColor.windowBackgroundColor))
            
            Rectangle()
                .fill(Color(NSColor.separatorColor))
                .frame(height: 0.5)
                
            // Compact form
            VStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Client ID")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    TextField("Reddit Client ID", text: $clientId)
                        .textFieldStyle(.plain)
                        .font(.system(size: 10, design: .monospaced))
                        .padding(6)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(4)
                }
                
                VStack(alignment: .leading, spacing: 3) {
                    Text("Client Secret")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    SecureField("Reddit Client Secret", text: $clientSecret)
                        .textFieldStyle(.plain)
                        .font(.system(size: 10, design: .monospaced))
                        .padding(6)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(4)
                }
                
                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.system(size: 8))
                        .padding(.top, 4)
                }
                
                Spacer()
                
                // Compact action buttons
                HStack(spacing: 8) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .font(.system(size: 9))
                    .buttonStyle(.bordered)
                    
                    Button(isLoading ? "Validating..." : "Save") {
                        saveCredentials()
                    }
                    .font(.system(size: 9))
                    .buttonStyle(.borderedProminent)
                    .disabled(clientId.isEmpty || clientSecret.isEmpty || isLoading)
                }
            }
            .padding(12)
            .background(Color(NSColor.controlBackgroundColor))
        }
        .frame(width: 520, height: 280)
        .sheet(isPresented: $showingHelp) {
            RedditSetupHelpView()
        }
        .onAppear {
            // Pre-fill if credentials already exist
            if let existingCredentials = credentialManager.getRedditCredentials() {
                clientId = existingCredentials.clientId
                clientSecret = existingCredentials.clientSecret
            }
        }
    }
    
    private func saveCredentials() {
        isLoading = true
        errorMessage = ""
        
        // Validate credentials
        let trimmedClientId = clientId.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedClientSecret = clientSecret.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard credentialManager.validateRedditCredentials(clientId: trimmedClientId, clientSecret: trimmedClientSecret) else {
            errorMessage = "Invalid credentials. Client ID should be at least 10 characters and Client Secret at least 20 characters."
            isLoading = false
            return
        }
        
        // Save credentials
        credentialManager.setRedditCredentials(clientId: trimmedClientId, clientSecret: trimmedClientSecret)
        
        // Test the credentials by attempting authentication
        Task {
            do {
                let redditAPI = RedditAPI()
                _ = try await redditAPI.fetchStories()
                
                await MainActor.run {
                    isLoading = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to authenticate with Reddit: \(error.localizedDescription)"
                    isLoading = false
                }
            }
        }
    }
}

struct RedditSetupHelpView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("How to get Reddit API Credentials")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        StepView(
                            number: 1,
                            title: "Go to Reddit App Preferences",
                            description: "Visit https://www.reddit.com/prefs/apps and log in to your Reddit account."
                        )
                        
                        StepView(
                            number: 2,
                            title: "Create a New App",
                            description: "Click 'Create App' or 'Create Another App' button."
                        )
                        
                        StepView(
                            number: 3,
                            title: "Fill App Details",
                            description: "Give your app a name (e.g., 'ReadGood'), select 'script' as the app type, and set redirect uri to 'http://localhost:8080'."
                        )
                        
                        StepView(
                            number: 4,
                            title: "Get Credentials",
                            description: "After creating the app, you'll see the Client ID (below the app name) and Client Secret. Copy these values."
                        )
                    }
                    
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Important Notes:")
                            .fontWeight(.semibold)
                        
                        Text("• Keep your credentials secure and don't share them")
                        Text("• Client ID is typically 14-22 characters")
                        Text("• Client Secret is typically 27+ characters") 
                        Text("• These credentials are stored locally on your Mac")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                .padding()
            }
            .navigationTitle("Reddit Setup Help")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .frame(minWidth: 500, minHeight: 400)
    }
}

struct StepView: View {
    let number: Int
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 20, height: 20)
                .background(Color.blue)
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

#Preview {
    RedditCredentialsView()
}