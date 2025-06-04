import Foundation

class ArchiveService {
    private let baseArchiveURL = "https://archive.ph"
    private let submissionURL = "https://dgy3yyibpm3nn7.archive.ph"
    
    func generateArchiveURL(for url: String) -> String {
        guard !url.isEmpty, let encodedURL = url.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return baseArchiveURL
        }
        return "\(submissionURL)/?url=\(encodedURL)"
    }
    
    func generateDirectArchiveURL(for url: String) -> String {
        guard !url.isEmpty, let encodedURL = url.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return baseArchiveURL
        }
        return "\(baseArchiveURL)/\(encodedURL)"
    }
    
    func archiveURL(for originalURL: String) async throws -> String {
        // This would submit to archive.ph and wait for the archived URL
        // For now, just return the direct URL
        return generateDirectArchiveURL(for: originalURL)
    }
}