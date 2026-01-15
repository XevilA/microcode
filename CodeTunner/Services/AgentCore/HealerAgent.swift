//
//  HealerAgent.swift
//  CodeTunner
//
//  Specialized AI Agent for Auto-Healing functionality.
//  Focuses on analyzing build errors and generating precise code fixes.
//

import Foundation
import Combine
import CodeTunnerSupport

@MainActor
class HealerAgent: ObservableObject {
    static let shared = HealerAgent()
    
    private let agent = AgentExecutor.shared
    
    /// Analyzes a build error or runtime exception and returns a fix suggestion
    /// - Parameters:
    ///   - error: The error message or log
    ///   - context: Using code snippets or file content
    ///   - filePath: The file path where the error occurred
    /// - Returns: A proposed fix description and diff
    func analyzeAndFix(error: String, codeContext: String, filePath: String, aiContext: AuthenticAIContext? = nil) async throws -> HealerSuggestion? {
        // Construct a specialized prompt
        var prompt = """
        I encountered a build error or runtime crash in my Swift project.
        
        File: \(filePath)
        
        Error Message:
        \(error)
        
        Code Context (around the error):
        ```swift
        \(codeContext)
        ```
        """
        
        if let ctx = aiContext {
            prompt += "\n\nSemantic Context:\n\(ctx.llmContextDescription())"
        }
        
        prompt += """
        \n
        Please analyze this error. If you can determine a fix:
        1. Explain the cause briefly.
        2. Provide the FIXED code block for the specific range.
        
        Your Goal: provide a replacement code block that fixes the issue.
        """
        
        // Temporarily override system prompt/behavior if needed, or just use the general agent
        // For V1, we use the general agent but prompt it specifically.
        
        let response = try await agent.run(task: prompt, systemPrompt: """
        You are an expert Swift debugger and code healer.
        Your job is to fix compilation errors and bugs based on logs.
        
        Analyze the error and the code.
        If you are confident in the fix, output the following structured response:
        
        SUMMARY: <Short description of fix>
        EXPLANATION: <Why it broke and why this fixes it>
        FIX_CODE:
        ```swift
        <The complete corrected block of code>
        ```
        
        Do NOT use tools. Just analyze and provide the code.
        """)
        
        return parseHealerResponse(response, filePath: filePath)
    }
    
    private func parseHealerResponse(_ response: String, filePath: String) -> HealerSuggestion? {
        guard response.contains("FIX_CODE:") else { return nil }
        
        var summary = "Fix detected"
        var explanation = ""
        var fixCode = ""
        
        // Simple manual parsing
        let lines = response.components(separatedBy: .newlines)
        var parsingCode = false
        
        for line in lines {
            if line.starts(with: "SUMMARY:") {
                summary = String(line.dropFirst(8)).trimmingCharacters(in: .whitespaces)
            } else if line.starts(with: "EXPLANATION:") {
                explanation = String(line.dropFirst(12)).trimmingCharacters(in: .whitespaces)
            } else if line.contains("FIX_CODE:") {
                // start looking for code block
            } else if line.trimmingCharacters(in: .whitespaces).hasPrefix("```swift") {
                parsingCode = true
            } else if line.trimmingCharacters(in: .whitespaces).hasPrefix("```") && parsingCode {
                parsingCode = false
            } else if parsingCode {
                fixCode += line + "\n"
            } else if !parsingCode && explanation.isEmpty && !line.starts(with: "SUMMARY:") {
                // Approximate explanation capture
                // explanation += line + " "
            }
        }
        
        guard !fixCode.isEmpty else { return nil }
        
        return HealerSuggestion(
            id: UUID(),
            summary: summary,
            explanation: explanation,
            filePath: filePath,
            originalError: "Error detected in file", 
            proposedCode: fixCode
        )
    }
}

struct HealerSuggestion: Identifiable, Equatable {
    let id: UUID
    let summary: String
    let explanation: String
    let filePath: String
    let originalError: String
    let proposedCode: String
}
