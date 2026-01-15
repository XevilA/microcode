//
//  AgentExecutor.swift
//  CodeTunner
//
//  Production-Grade AI Agent - Main Executor
//

import Foundation
import SwiftUI
import CodeTunnerSupport

// MARK: - Agent Executor

@MainActor
class AgentExecutor: ObservableObject {
    static let shared = AgentExecutor()
    
    @Published var currentTask: String = ""
    @Published var steps: [ExecutionStep] = []
    @Published var isRunning: Bool = false
    @Published var progress: Double = 0.0
    @Published var finalResult: String?
    
    let toolBox = AgentToolBox.shared
    let memory = AgentMemory.shared
    let session = AgentSession.shared
    
    private var maxIterations = 10
    
    // MARK: - Run Agent
    
    func run(task: String, systemPrompt: String? = nil) async throws -> String {
        currentTask = task
        steps = []
        isRunning = true
        progress = 0.0
        finalResult = nil
        
        defer { isRunning = false }
        
        // Fetch Real-time Context from Smart Core
        let contextDescription: String
        if let context = AuthenticLanguageCore.shared().aiContext() {
            contextDescription = """
            
            CURRENT CODE CONTEXT:
            \(context.llmContextDescription)
            """
        } else {
            contextDescription = ""
        }

        let defaultSystemPrompt = """
        You are an AI coding assistant that follows the ReAct (Reason + Act) pattern.
        You have access to the current code context and tools to manipulate the project.
        
        \(contextDescription)
        
        Available tools:
        \(toolBox.toolDescriptions)
        
        For each step:
        1. Think: Analyze the request and the current context. Plan your actions.
        2. Act: Use tools to inspect or modify files. Respond EXACTLY with:
           ACTION: tool_name(param1="value1", param2="value2")
        3. Observe: I will provide the tool output.
        4. Repeat until complete.
        5. When done, respond with:
           FINAL ANSWER: <your complete summary>
        
        Rules:
        - Use `file_read` to check content before editing.
        - Use `file_search` to find files.
        - Be precise with tool parameters.
        - If the user refers to "this function" or "local variable", look at the CURRENT CODE CONTEXT.
        """
        
        let systemMessage = systemPrompt ?? defaultSystemPrompt
        var conversationHistory: [[String: String]] = [
            ["role": "system", "content": systemMessage],
            ["role": "user", "content": task]
        ]
        
        memory.remember(task, type: .task)
        
        for iteration in 0..<maxIterations {
            progress = Double(iteration) / Double(maxIterations)
            
            // Build prompt with history
            let prompt = conversationHistory.map { "\($0["role"]!): \($0["content"]!)" }.joined(separator: "\n\n")
            
            // Get LLM response
            let response = try await session.generate(prompt: prompt)
            
            addStep(.thought(content: response, iteration: iteration))
            conversationHistory.append(["role": "assistant", "content": response])
            
            // Check for final answer
            if response.uppercased().contains("FINAL ANSWER:") {
                let answer = extractFinalAnswer(response)
                addStep(.finalAnswer(content: answer))
                finalResult = answer
                memory.remember(answer, type: .general)
                progress = 1.0
                return answer
            }
            
            // Parse and execute tool call
            if let toolCall = parseToolCall(response) {
                addStep(.action(tool: toolCall.name, params: toolCall.params))
                
                do {
                    let result = try await toolBox.execute(toolCall.name, params: toolCall.params)
                    addStep(.observation(content: result))
                    conversationHistory.append(["role": "user", "content": "Tool result: \(result)"])
                    memory.remember("Tool \(toolCall.name): \(result)", type: .general)
                } catch {
                    let errorMsg = "Error: \(error.localizedDescription)"
                    addStep(.error(content: errorMsg))
                    conversationHistory.append(["role": "user", "content": errorMsg])
                }
            }
        }
        
        // Max iterations reached
        let timeoutMsg = "Agent reached maximum iterations without completing the task."
        finalResult = timeoutMsg
        return timeoutMsg
    }
    
    // MARK: - Helpers
    
    private func addStep(_ step: ExecutionStep) {
        steps.append(step)
    }
    
    private func parseToolCall(_ text: String) -> (name: String, params: [String: Any])? {
        let pattern = #"ACTION:\s*(\w+)\((.*?)\)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) else {
            return nil
        }
        
        if let nameRange = Range(match.range(at: 1), in: text),
           let paramsRange = Range(match.range(at: 2), in: text) {
            let name = String(text[nameRange])
            let paramsStr = String(text[paramsRange])
            let params = parseParams(paramsStr)
            return (name, params)
        }
        return nil
    }
    
    private func parseParams(_ str: String) -> [String: Any] {
        var params: [String: Any] = [:]
        
        // Parse key="value" format
        let kvPattern = #"(\w+)\s*=\s*\"([^\"]*)\""#
        if let regex = try? NSRegularExpression(pattern: kvPattern) {
            let matches = regex.matches(in: str, range: NSRange(str.startIndex..., in: str))
            for match in matches {
                if let keyRange = Range(match.range(at: 1), in: str),
                   let valueRange = Range(match.range(at: 2), in: str) {
                    params[String(str[keyRange])] = String(str[valueRange])
                }
            }
        }
        
        // If no key=value, parse positional args
        if params.isEmpty {
            let parts = str.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            for (index, part) in parts.enumerated() {
                params["arg\(index)"] = part.trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
            }
        }
        
        return params
    }
    
    private func extractFinalAnswer(_ text: String) -> String {
        let patterns = ["FINAL ANSWER:", "Final Answer:", "final answer:"]
        for pattern in patterns {
            if let range = text.range(of: pattern, options: .caseInsensitive) {
                return String(text[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return text
    }
    
    func cancel() {
        isRunning = false
    }
    
    func reset() {
        currentTask = ""
        steps = []
        isRunning = false
        progress = 0.0
        finalResult = nil
    }
}

// MARK: - Execution Step

enum ExecutionStep: Identifiable {
    case thought(content: String, iteration: Int)
    case action(tool: String, params: [String: Any])
    case observation(content: String)
    case error(content: String)
    case finalAnswer(content: String)
    
    var id: UUID { UUID() }
    
    var icon: String {
        switch self {
        case .thought: return "brain"
        case .action: return "hammer"
        case .observation: return "eye"
        case .error: return "exclamationmark.triangle"
        case .finalAnswer: return "checkmark.circle"
        }
    }
    
    var color: Color {
        switch self {
        case .thought: return .purple
        case .action: return .blue
        case .observation: return .green
        case .error: return .red
        case .finalAnswer: return .orange
        }
    }
    
    var title: String {
        switch self {
        case .thought(_, let iter): return "Thought #\(iter + 1)"
        case .action(let tool, _): return "Action: \(tool)"
        case .observation: return "Observation"
        case .error: return "Error"
        case .finalAnswer: return "Final Answer"
        }
    }
    
    var content: String {
        switch self {
        case .thought(let c, _): return c
        case .action(_, let params): return params.map { "\($0): \($1)" }.joined(separator: ", ")
        case .observation(let c): return c
        case .error(let c): return c
        case .finalAnswer(let c): return c
        }
    }
}
