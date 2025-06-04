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
        NavigationView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "globe")
                        .font(.system(size: 48))
                        .foregroundColor(.orange)
                    
                    Text("Activate Reddit Integration")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Enter your Reddit API credentials to fetch stories from Reddit")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top)
                
                // Form
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Client ID")
                                .fontWeight(.medium)
                            
                            Button(action: { showingHelp = true }) {
                                Image(systemName: "questionmark.circle")
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        
                        TextField("Enter Reddit Client ID", text: $clientId)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .font(.system(.body, design: .monospaced))
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Client Secret")
                            .fontWeight(.medium)
                        
                        SecureField("Enter Reddit Client Secret", text: $clientSecret)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .font(.system(.body, design: .monospaced))
                    }
                    
                    if !errorMessage.isEmpty {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Action buttons
                HStack(spacing: 12) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Save Credentials") {
                        saveCredentials()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(clientId.isEmpty || clientSecret.isEmpty || isLoading)
                }
                .padding(.bottom)
            }
            .frame(minWidth: 400, minHeight: 300)
            .navigationTitle("Reddit Setup")
        }
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