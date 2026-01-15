//
//  AgentStep.swift
//  CodeTunner
//
//  Production-Grade AI Agent - Step Protocol
//  Inspired by SwiftAgent SDK and rust-agentai
//

import Foundation

// MARK: - Step Protocol

/// A composable unit of work in an agent pipeline
public protocol AgentStep: Sendable {
    associatedtype Input: Sendable
    associatedtype Output: Sendable
    
    func run(_ input: Input) async throws -> Output
}

// MARK: - Step Types

/// Transform step - converts input to output
struct TransformStep<I: Sendable, O: Sendable>: AgentStep {
    typealias Input = I
    typealias Output = O
    
    let transform: @Sendable (I) async throws -> O
    
    func run(_ input: I) async throws -> O {
        return try await transform(input)
    }
}

/// Map step - transforms with context
struct MapStep<I: Sendable, O: Sendable>: AgentStep {
    typealias Input = I
    typealias Output = O
    
    let context: Any?
    let mapper: @Sendable (I, Any?) async throws -> O
    
    func run(_ input: I) async throws -> O {
        return try await mapper(input, context)
    }
}

/// Sequence step - chains multiple steps
struct SequenceStep<A: AgentStep, B: AgentStep>: AgentStep where A.Output == B.Input {
    typealias Input = A.Input
    typealias Output = B.Output
    
    let first: A
    let second: B
    
    func run(_ input: A.Input) async throws -> B.Output {
        let intermediate = try await first.run(input)
        return try await second.run(intermediate)
    }
}

/// Loop step - repeats until condition
struct LoopStep<S: AgentStep>: AgentStep where S.Input == S.Output {
    typealias Input = S.Input
    typealias Output = S.Output
    
    let step: S
    let maxIterations: Int
    let shouldContinue: @Sendable (S.Output) -> Bool
    
    func run(_ input: S.Input) async throws -> S.Output {
        var result = input
        for _ in 0..<maxIterations {
            result = try await step.run(result)
            if !shouldContinue(result) { break }
        }
        return result
    }
}

/// Parallel step - runs steps concurrently
struct ParallelStep<S: AgentStep>: AgentStep {
    typealias Input = [S.Input]
    typealias Output = [S.Output]
    
    let step: S
    
    func run(_ inputs: [S.Input]) async throws -> [S.Output] {
        return try await withThrowingTaskGroup(of: (Int, S.Output).self) { group in
            for (index, input) in inputs.enumerated() {
                group.addTask {
                    let result = try await self.step.run(input)
                    return (index, result)
                }
            }
            
            var results = [S.Output?](repeating: nil, count: inputs.count)
            for try await (index, output) in group {
                results[index] = output
            }
            return results.compactMap { $0 }
        }
    }
}

// MARK: - ReAct Step (Reason + Act)

/// The core ReAct pattern step
@MainActor
struct ReActStep {
    let toolBox: AgentToolBox
    let maxIterations: Int
    let llmCall: @Sendable (String, [AgentMessage]) async throws -> String
    
    func run(_ input: AgentContext) async throws -> AgentContext {
        var context = input
        
        // Get tool descriptions on main actor
        let toolDescs = toolBox.toolDescriptions
        
        for iteration in 0..<maxIterations {
            // Phase 1: Think
            let thinkPrompt = buildThinkPrompt(context, toolDescriptions: toolDescs)
            let thought = try await llmCall(thinkPrompt, context.messages)
            
            context.addStep(.thought(iteration: iteration, content: thought))
            
            // Check if done
            if thought.lowercased().contains("final answer:") {
                let answer = extractFinalAnswer(thought)
                context.addStep(.finalAnswer(content: answer))
                context.finalAnswer = answer
                break
            }
            
            // Phase 2: Act - Parse tool call
            if let toolCall = parseToolCall(thought) {
                context.addStep(.action(tool: toolCall.name, params: toolCall.params))
                
                // Phase 3: Observe - Execute tool
                do {
                    let result = try await toolBox.execute(toolCall.name, params: toolCall.params)
                    context.addStep(.observation(content: result))
                    context.addMessage(role: .tool, content: "Tool result: \(result)")
                } catch {
                    context.addStep(.observation(content: "Error: \(error.localizedDescription)"))
                    context.addMessage(role: .tool, content: "Tool error: \(error.localizedDescription)")
                }
            }
        }
        
        return context
    }
    
    private func buildThinkPrompt(_ context: AgentContext, toolDescriptions: String) -> String {
        """
        You are an AI agent that follows the ReAct pattern.
        
        Available tools:
        \(toolDescriptions)
        
        Current task: \(context.task)
        
        Think step by step. For each step:
        1. Thought: Analyze what you need to do next
        2. Action: Call a tool if needed using format: ACTION: tool_name(param1, param2)
        3. When done, respond with: Final Answer: <your answer>
        
        Previous steps:
        \(context.stepsDescription)
        
        What is your next thought and action?
        """
    }
    
    private func parseToolCall(_ text: String) -> (name: String, params: [String: Any])? {
        // Parse ACTION: tool_name(params)
        let pattern = #"ACTION:\s*(\w+)\((.*?)\)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) else {
            return nil
        }
        
        if let nameRange = Range(match.range(at: 1), in: text),
           let paramsRange = Range(match.range(at: 2), in: text) {
            let name = String(text[nameRange])
            let paramsStr = String(text[paramsRange])
            // Simple param parsing
            let params = parseParams(paramsStr)
            return (name, params)
        }
        return nil
    }
    
    private func parseParams(_ str: String) -> [String: Any] {
        var params: [String: Any] = [:]
        let parts = str.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        for (index, part) in parts.enumerated() {
            if part.contains("=") {
                let kv = part.split(separator: "=", maxSplits: 1)
                if kv.count == 2 {
                    params[String(kv[0]).trimmingCharacters(in: .whitespaces)] = String(kv[1]).trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
                }
            } else {
                params["arg\(index)"] = part.trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
            }
        }
        return params
    }
    
    private func extractFinalAnswer(_ text: String) -> String {
        if let range = text.range(of: "Final Answer:", options: .caseInsensitive) {
            return String(text[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return text
    }
}

// MARK: - Agent Context

struct AgentContext: Sendable {
    var task: String
    var messages: [AgentMessage]
    var steps: [AgentStepRecord]
    var memory: [String: String]
    var finalAnswer: String?
    
    init(task: String) {
        self.task = task
        self.messages = [AgentMessage(role: .user, content: task)]
        self.steps = []
        self.memory = [:]
    }
    
    mutating func addMessage(role: AgentMessage.Role, content: String) {
        messages.append(AgentMessage(role: role, content: content))
    }
    
    mutating func addStep(_ step: AgentStepRecord) {
        steps.append(step)
    }
    
    var stepsDescription: String {
        steps.map { $0.description }.joined(separator: "\n")
    }
}

struct AgentMessage: Sendable {
    enum Role: String, Sendable {
        case user
        case assistant
        case tool
        case system
    }
    
    let role: Role
    let content: String
    let timestamp: Date
    
    init(role: Role, content: String) {
        self.role = role
        self.content = content
        self.timestamp = Date()
    }
}

enum AgentStepRecord: Sendable {
    case thought(iteration: Int, content: String)
    case action(tool: String, params: [String: Any])
    case observation(content: String)
    case finalAnswer(content: String)
    
    var description: String {
        switch self {
        case .thought(let iter, let content):
            return "Thought[\(iter)]: \(content)"
        case .action(let tool, let params):
            return "Action: \(tool)(\(params))"
        case .observation(let content):
            return "Observation: \(content)"
        case .finalAnswer(let content):
            return "Final Answer: \(content)"
        }
    }
}

// Sendable conformance for AgentStepRecord
extension AgentStepRecord: @unchecked Sendable {}
