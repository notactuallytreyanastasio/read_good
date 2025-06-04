import Foundation

struct RedditCredentials {
    let clientId: String
    let clientSecret: String
}

class CredentialManager: ObservableObject {
    static let shared = CredentialManager()
    
    private let userDefaults = UserDefaults.standard
    private let redditClientIdKey = "RedditClientId"
    private let redditClientSecretKey = "RedditClientSecret"
    
    private init() {}
    
    var hasRedditCredentials: Bool {
        return getRedditCredentials() != nil
    }
    
    func getRedditCredentials() -> RedditCredentials? {
        guard let clientId = userDefaults.string(forKey: redditClientIdKey),
              let clientSecret = userDefaults.string(forKey: redditClientSecretKey),
              !clientId.isEmpty,
              !clientSecret.isEmpty else {
            return nil
        }
        
        return RedditCredentials(clientId: clientId, clientSecret: clientSecret)
    }
    
    func setRedditCredentials(clientId: String, clientSecret: String) {
        userDefaults.set(clientId, forKey: redditClientIdKey)
        userDefaults.set(clientSecret, forKey: redditClientSecretKey)
        objectWillChange.send()
    }
    
    func clearRedditCredentials() {
        userDefaults.removeObject(forKey: redditClientIdKey)
        userDefaults.removeObject(forKey: redditClientSecretKey)
        objectWillChange.send()
    }
    
    func validateRedditCredentials(clientId: String, clientSecret: String) -> Bool {
        // Basic validation - ensure credentials have minimum length requirements
        return clientId.count >= 10 && clientSecret.count >= 20
    }
}