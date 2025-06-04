import Foundation

class ClaudeService: @unchecked Sendable {
    private let session = URLSession.shared
    
    func generateTags(title: String, url: String?) async throws -> ClaudeTagResult {
        print("🤖 Starting Claude tag generation for: \(title)")
        
        let prompt = """
        Based on this article title\(url != nil ? " and URL" : ""), suggest 4-6 relevant tags that would help categorize and find this content later.
        
        Title: "\(title)"\(url != nil ? "\nURL: \(url!)" : "")
        
        Please provide tags that are:
        - Descriptive and specific
        - Useful for categorization
        - Common enough to group similar articles
        - A mix of topics, technologies, and themes
        - NOT synonyms with one another
        
        Return only the tags as a comma-separated list, no explanations.
        """
        
        // Try multiple methods like the original Electron version
        
        // Method 1: Try Claude CLI first
        if await isClaudeAvailable() {
            do {
                print("💻 Trying Claude CLI...")
                let tags = try await callClaudeCLI(prompt: prompt)
                print("✅ Claude CLI succeeded with \(tags.count) tags")
                return ClaudeTagResult(success: true, tags: tags, source: "claude-cli", error: nil)
            } catch {
                print("❌ Claude CLI failed: \(error)")
            }
        }
        
        // Method 2: Try HTTP API on common ports
        do {
            print("🌐 Trying Claude HTTP API...")
            let result = try await tryClaudeHttpAPI(prompt: prompt)
            if result.success {
                print("✅ HTTP API succeeded on \(result.source ?? "unknown")")
                return result
            }
        } catch {
            print("❌ Claude HTTP API failed: \(error)")
        }
        
        // Method 3: Check if Claude Desktop app exists
        if await isClaudeDesktopInstalled() {
            print("📱 Claude Desktop app found, but AppleScript not implemented")
            // TODO: Implement AppleScript method if needed
        }
        
        print("❌ All Claude integration methods failed")
        return ClaudeTagResult(success: false, tags: [], source: nil, error: "Claude integration failed - ensure Claude CLI is installed and accessible")
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
                let available = process.terminationStatus == 0
                if available {
                    print("✅ Claude CLI found in PATH")
                } else {
                    print("❌ Claude CLI not found in PATH")
                }
                continuation.resume(returning: available)
            } catch {
                print("❌ Error checking Claude CLI: \(error)")
                continuation.resume(returning: false)
            }
        }
    }
    
    private func isClaudeDesktopInstalled() async -> Bool {
        let possiblePaths = [
            "/Applications/Claude.app",
            "/System/Applications/Claude.app", 
            "/Applications/Utilities/Claude.app"
        ]
        
        for path in possiblePaths {
            if FileManager.default.fileExists(atPath: path) {
                print("✅ Found Claude Desktop at \(path)")
                return true
            }
        }
        
        print("❌ Claude Desktop app not found")
        return false
    }
    
    private func tryClaudeHttpAPI(prompt: String) async throws -> ClaudeTagResult {
        let ports = [3000, 8080, 9000, 52000, 52001]
        
        for port in ports {
            do {
                let url = URL(string: "http://localhost:\(port)/api/chat")!
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.setValue("ReadGood-TagGenerator/1.0", forHTTPHeaderField: "User-Agent")
                request.timeoutInterval = 10.0
                
                let body: [String: Any] = [
                    "message": prompt,
                    "max_tokens": 100
                ]
                request.httpBody = try JSONSerialization.data(withJSONObject: body)
                
                let (data, _) = try await session.data(for: request)
                
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let response = json["response"] as? String ?? json["message"] as? String {
                    let tags = try parseClaudeResponse(response)
                    return ClaudeTagResult(success: true, tags: tags, source: "claude-http-\(port)", error: nil)
                }
            } catch {
                // Continue to next port
                continue
            }
        }
        
        throw ClaudeError.invalidResponse("No working HTTP API found on any port")
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
                    process.waitUntilExit()
                    
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

struct ClaudeTagResult {
    let success: Bool
    let tags: [String]
    let source: String?
    let error: String?
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