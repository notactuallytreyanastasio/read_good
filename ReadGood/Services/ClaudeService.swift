import Foundation

class ClaudeService {
    private let session = URLSession.shared
    
    func generateTags(title: String, url: String) async throws -> [String] {
        // Check if Claude CLI is available
        guard await isClaudeAvailable() else {
            throw ClaudeError.claudeNotAvailable
        }
        
        let prompt = """
        Based on this article title and URL, suggest 4-6 relevant tags that would help categorize and find this content later.
        
        Title: "\(title)"
        URL: \(url)
        
        Please provide tags that are:
        - Descriptive and specific
        - Useful for categorization
        - Common enough to group similar articles
        - A mix of topics, technologies, and themes
        - NOT synonyms with one another
        
        Return only the tags as a comma-separated list, no explanations.
        """
        
        do {
            let tags = try await callClaudeCLI(prompt: prompt)
            print("Generated \(tags.count) AI tags for: \(title)")
            return tags
        } catch {
            print("Claude tag generation failed: \(error)")
            throw error
        }
    }
    
    private func isClaudeAvailable() async -> Bool {
        return await withCheckedContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
            process.arguments = ["claude"]
            process.standardOutput = Pipe()
            process.standardError = Pipe()
            
            do {
                try process.run()
                process.waitUntilExit()
                continuation.resume(returning: process.terminationStatus == 0)
            } catch {
                continuation.resume(returning: false)
            }
        }
    }
    
    private func callClaudeCLI(prompt: String) async throws -> [String] {
        return try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = ["claude", "--print", "--output-format=text"]
            
            let inputPipe = Pipe()
            let outputPipe = Pipe()
            let errorPipe = Pipe()
            
            process.standardInput = inputPipe
            process.standardOutput = outputPipe
            process.standardError = errorPipe
            
            do {
                try process.run()
                
                // Send prompt to Claude
                let inputData = prompt.data(using: .utf8) ?? Data()
                inputPipe.fileHandleForWriting.write(inputData)
                inputPipe.fileHandleForWriting.closeFile()
                
                // Wait for completion with timeout
                DispatchQueue.global().async {
                    let timeout = DispatchTime.now() + .seconds(15)
                    let result = process.waitUntilExit()
                    
                    if DispatchTime.now() < timeout {
                        if process.terminationStatus == 0 {
                            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                            if let output = String(data: outputData, encoding: .utf8) {
                                do {
                                    let tags = try self.parseClaudeResponse(output)
                                    continuation.resume(returning: tags)
                                } catch {
                                    continuation.resume(throwing: error)
                                }
                            } else {
                                continuation.resume(throwing: ClaudeError.invalidResponse("No output from Claude"))
                            }
                        } else {
                            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                            let errorString = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                            continuation.resume(throwing: ClaudeError.processError("Claude process failed: \(errorString)"))
                        }
                    } else {
                        process.terminate()
                        continuation.resume(throwing: ClaudeError.timeout("Claude request timed out"))
                    }
                }
                
            } catch {
                continuation.resume(throwing: ClaudeError.processError("Failed to start Claude process: \(error)"))
            }
        }
    }
    
    private func parseClaudeResponse(_ response: String) throws -> [String] {
        let cleanResponse = response.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !cleanResponse.isEmpty else {
            throw ClaudeError.invalidResponse("Empty response from Claude")
        }
        
        // Remove markdown formatting
        let withoutMarkdown = cleanResponse
            .replacingOccurrences(of: "```", with: "")
            .replacingOccurrences(of: "`", with: "")
        
        // Look for comma-separated tags
        let lines = withoutMarkdown.components(separatedBy: .newlines)
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Skip empty lines and explanatory text
            if trimmedLine.isEmpty ||
               trimmedLine.lowercased().contains("here are") ||
               trimmedLine.lowercased().contains("based on") ||
               trimmedLine.lowercased().contains("suggested tags") ||
               trimmedLine.count > 200 {
                continue
            }
            
            // Check if this line contains comma-separated words
            if trimmedLine.contains(",") {
                let tags = trimmedLine.components(separatedBy: ",")
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
                    .filter { !$0.isEmpty && $0.count < 30 && !$0.contains(".") }
                    .prefix(8) // Max 8 tags
                
                if tags.count >= 2 {
                    return Array(tags)
                }
            }
        }
        
        // Fallback: extract individual words
        let words = cleanResponse
            .lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { $0.count > 2 && $0.count < 20 && !$0.contains(".") }
            .prefix(6)
        
        if !words.isEmpty {
            return Array(words)
        }
        
        throw ClaudeError.invalidResponse("No valid tags found in Claude response")
    }
}

enum ClaudeError: Error, LocalizedError {
    case claudeNotAvailable
    case timeout(String)
    case processError(String)
    case invalidResponse(String)
    
    var errorDescription: String? {
        switch self {
        case .claudeNotAvailable:
            return "Claude CLI is not available"
        case .timeout(let message),
             .processError(let message),
             .invalidResponse(let message):
            return message
        }
    }
}