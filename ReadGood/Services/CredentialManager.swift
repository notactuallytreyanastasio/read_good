import Foundation

class CredentialManager: ObservableObject {
    static let shared = CredentialManager()
    
    @Published var hasRedditCredentials: Bool = false
    
    private let redditClientIdKey = "reddit_client_id"
    private let redditClientSecretKey = "reddit_client_secret"
    
    private init() {
        checkRedditCredentials()
    }
    
    // MARK: - Reddit Credentials
    
    func setRedditCredentials(clientId: String, clientSecret: String) {
        UserDefaults.standard.set(clientId, forKey: redditClientIdKey)
        UserDefaults.standard.set(clientSecret, forKey: redditClientSecretKey)
        checkRedditCredentials()
        print("✅ Reddit credentials saved")
    }
    
    func getRedditCredentials() -> (clientId: String, clientSecret: String)? {
        guard let clientId = UserDefaults.standard.string(forKey: redditClientIdKey),
              let clientSecret = UserDefaults.standard.string(forKey: redditClientSecretKey),
              !clientId.isEmpty,
              !clientSecret.isEmpty else {
            return nil
        }
        
        return (clientId: clientId, clientSecret: clientSecret)
    }
    
    func clearRedditCredentials() {
        UserDefaults.standard.removeObject(forKey: redditClientIdKey)
        UserDefaults.standard.removeObject(forKey: redditClientSecretKey)
        checkRedditCredentials()
        print("🗑️ Reddit credentials cleared")
    }
    
    private func checkRedditCredentials() {
        hasRedditCredentials = getRedditCredentials() != nil
    }
    
    // MARK: - Validation
    
    func validateRedditCredentials(clientId: String, clientSecret: String) -> Bool {
        return !clientId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
               !clientSecret.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
               clientId.count >= 10 && // Reddit client IDs are typically longer
               clientSecret.count >= 20 // Reddit client secrets are typically longer
    }
}