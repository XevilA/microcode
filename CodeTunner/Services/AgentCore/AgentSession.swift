//
//  AgentSession.swift
//  CodeTunner
//
//  Production-Grade AI Agent - Provider-Agnostic Sessions
//

import Foundation

// MARK: - Agent Session

@MainActor
class AgentSession: ObservableObject {
    static let shared = AgentSession()
    
    @Published var provider: LLMProvider = .gemini
    @Published var model: String = "gemini-2.5-flash"
    @Published var apiKey: String = ""
    @Published var isStreaming: Bool = false
    @Published var temperature: Double = 0.7
    @Published var maxTokens: Int = 4096
    
    // MARK: - Providers
    
    enum LLMProvider: String, CaseIterable {
        case openai = "OpenAI"
        case gemini = "Gemini"
        case anthropic = "Anthropic"
        case ollama = "Ollama"
        case hybrid = "Hybrid (Rust + Cloud)"
        
        var models: [String] {
            switch self {
            case .openai: return ["gpt-4o", "gpt-4o-mini", "gpt-4-turbo", "o1-preview"]
            case .gemini: return ["gemini-2.5-flash", "gemini-2.5-pro", "gemini-2.0-flash"]
            case .anthropic: return ["claude-3-5-sonnet", "claude-3-opus", "claude-3-haiku"]
            case .ollama: return ["llama3.2", "codellama", "mistral", "mixtral"]
            case .hybrid: return ["fast-tier (local)", "smart-tier (cloud)"]
            }
        }
        
        var baseURL: String {
            switch self {
            case .openai: return "https://api.openai.com/v1"
            case .gemini: return "https://generativelanguage.googleapis.com/v1beta"
            case .anthropic: return "https://api.anthropic.com/v1"
            case .ollama: return "http://localhost:11434/api"
            case .hybrid: return "http://127.0.0.1:3000/api"
            }
        }
    }
    
    // MARK: - Generate
    
    func generate(prompt: String, systemPrompt: String? = nil) async throws -> String {
        switch provider {
        case .openai:
            return try await generateOpenAI(prompt: prompt, systemPrompt: systemPrompt)
        case .gemini:
            return try await generateGemini(prompt: prompt, systemPrompt: systemPrompt)
        case .anthropic:
            return try await generateAnthropic(prompt: prompt, systemPrompt: systemPrompt)
        case .ollama:
            return try await generateOllama(prompt: prompt, systemPrompt: systemPrompt)
        case .hybrid:
            return try await generateHybrid(prompt: prompt, systemPrompt: systemPrompt)
        }
    }
    
    // MARK: - Provider Implementations
    
    private func generateOpenAI(prompt: String, systemPrompt: String?) async throws -> String {
        let url = URL(string: "\(LLMProvider.openai.baseURL)/chat/completions")!
        
        var messages: [[String: Any]] = []
        if let sys = systemPrompt {
            messages.append(["role": "system", "content": sys])
        }
        messages.append(["role": "user", "content": prompt])
        
        let body: [String: Any] = [
            "model": model,
            "messages": messages,
            "temperature": temperature,
            "max_tokens": maxTokens
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        
        if let choices = json?["choices"] as? [[String: Any]],
           let message = choices.first?["message"] as? [String: Any],
           let content = message["content"] as? String {
            return content
        }
        
        throw SessionError.invalidResponse
    }
    
    private func generateGemini(prompt: String, systemPrompt: String?) async throws -> String {
        let fullPrompt = systemPrompt.map { "\($0)\n\n" } ?? "" + prompt
        
        let url = URL(string: "\(LLMProvider.gemini.baseURL)/models/\(model):generateContent?key=\(apiKey)")!
        
        let body: [String: Any] = [
            "contents": [
                ["parts": [["text": fullPrompt]]]
            ],
            "generationConfig": [
                "temperature": temperature,
                "maxOutputTokens": maxTokens
            ]
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        
        if let candidates = json?["candidates"] as? [[String: Any]],
           let content = candidates.first?["content"] as? [String: Any],
           let parts = content["parts"] as? [[String: Any]],
           let text = parts.first?["text"] as? String {
            return text
        }
        
        throw SessionError.invalidResponse
    }
    
    private func generateAnthropic(prompt: String, systemPrompt: String?) async throws -> String {
        let url = URL(string: "\(LLMProvider.anthropic.baseURL)/messages")!
        
        var body: [String: Any] = [
            "model": model,
            "messages": [["role": "user", "content": prompt]],
            "max_tokens": maxTokens
        ]
        
        if let sys = systemPrompt {
            body["system"] = sys
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        
        if let content = json?["content"] as? [[String: Any]],
           let text = content.first?["text"] as? String {
            return text
        }
        
        throw SessionError.invalidResponse
    }
    
    private func generateOllama(prompt: String, systemPrompt: String?) async throws -> String {
        let url = URL(string: "\(LLMProvider.ollama.baseURL)/generate")!
        
        var body: [String: Any] = [
            "model": model,
            "prompt": prompt,
            "stream": false
        ]
        
        if let sys = systemPrompt {
            body["system"] = sys
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        
        if let response = json?["response"] as? String {
            return response
        }
        
        throw SessionError.invalidResponse
    }

    private func generateHybrid(prompt: String, systemPrompt: String?) async throws -> String {
        // Calls the local Rust backend (FastTier / Hybrid Engine)
        let url = URL(string: "\(LLMProvider.hybrid.baseURL)/ai/complete")!
        
        let fullPrompt = (systemPrompt ?? "") + "\n" + prompt
        
        let body: [String: Any] = [
            "context_before": fullPrompt, // Treating prompt as context for completion
            "context_after": "",
            "file_path": NSNull()
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        
        // Response format: { "completion": "...", "latency_ms": 123 }
        if let completion = json?["completion"] as? String {
            return completion
        }
        
        if let err = json?["Err"] as? String {
             throw SessionError.apiError(err)
        }
        
        throw SessionError.invalidResponse
    }
}

enum SessionError: LocalizedError {
    case invalidResponse
    case apiError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse: return "Invalid response from AI provider"
        case .apiError(let msg): return "API Error: \(msg)"
        }
    }
}
