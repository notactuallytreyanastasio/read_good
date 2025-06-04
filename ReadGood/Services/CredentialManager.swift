import Foundation

struct RedditCredentials {
    let clientId: String
    let clientSecret: String
}

class CredentialManager: ObservableObject {
    static let shared = CredentialManager()
    
    private init() {}
    
    var hasRedditCredentials: Bool {
        return getRedditCredentials() != nil
    }
    
    func getRedditCredentials() -> RedditCredentials? {
        // For now, return nil to indicate no credentials are configured
        // This can be extended later to store/retrieve credentials securely
        return nil
    }
    
    func setRedditCredentials(clientId: String, clientSecret: String) {
        // TODO: Implement secure credential storage
        // For now, this is a placeholder
    }
    
    func clearRedditCredentials() {
        // TODO: Implement credential clearing
        // For now, this is a placeholder
    }
    
    func validateRedditCredentials(clientId: String, clientSecret: String) -> Bool {
        // Basic validation - ensure credentials have minimum length requirements
        return clientId.count >= 10 && clientSecret.count >= 20
    }
}