//
//  AgentMemory.swift
//  CodeTunner
//
//  Production-Grade AI Agent - Memory System
// SPU AI CLUB
// Arsenal
// Dotmini Software
//
// Contact Us:
// IG: tirawat_nn
// Line ID: alone0603
// GitHub: github.com/XevilA

import Foundation

// MARK: - Agent Memory

@MainActor
class AgentMemory: ObservableObject {
    static let shared = AgentMemory()
    
    @Published var conversations: [String: Conversation] = [:]
    @Published var shortTermMemory: [MemoryItem] = []
    @Published var longTermMemory: [MemoryItem] = []
    
    private let maxShortTermItems = 50
    private let maxContextTokens = 8000
    
    // MARK: - Conversation Management
    
    func getOrCreateConversation(id: String = UUID().uuidString) -> Conversation {
        if let existing = conversations[id] {
            return existing
        }
        let new = Conversation(id: id)
        conversations[id] = new
        return new
    }
    
    func addMessage(to conversationId: String, role: String, content: String) {
        guard var conversation = conversations[conversationId] else { return }
        conversation.messages.append(ConversationMessage(role: role, content: content))
        conversations[conversationId] = conversation
    }
    
    // MARK: - Short Term Memory
    
    func remember(_ content: String, type: MemoryType = .general) {
        let item = MemoryItem(content: content, type: type)
        shortTermMemory.insert(item, at: 0)
        
        // Trim if too many
        if shortTermMemory.count > maxShortTermItems {
            shortTermMemory = Array(shortTermMemory.prefix(maxShortTermItems))
        }
    }
    
    func commitToLongTerm(_ item: MemoryItem) {
        longTermMemory.insert(item, at: 0)
    }
    
    // MARK: - Context Building
    
    func buildContext(for task: String, maxTokens: Int = 4000) -> String {
        var context = ""
        var tokenCount = 0
        
        // Recent short-term memories
        for item in shortTermMemory.prefix(10) {
            let itemTokens = item.content.count / 4 // Rough estimate
            if tokenCount + itemTokens > maxTokens { break }
            context += "[\(item.type.rawValue)] \(item.content)\n"
            tokenCount += itemTokens
        }
        
        return context
    }
    
    // MARK: - Search
    
    func search(query: String) -> [MemoryItem] {
        let queryLower = query.lowercased()
        return (shortTermMemory + longTermMemory).filter {
            $0.content.lowercased().contains(queryLower)
        }
    }
    
    func clear() {
        shortTermMemory.removeAll()
        conversations.removeAll()
    }
}

// MARK: - Models

struct Conversation: Identifiable {
    let id: String
    var messages: [ConversationMessage] = []
    let createdAt = Date()
    var updatedAt = Date()
    
    var messageCount: Int { messages.count }
    
    mutating func addMessage(role: String, content: String) {
        messages.append(ConversationMessage(role: role, content: content))
        updatedAt = Date()
    }
}

struct ConversationMessage: Identifiable {
    let id = UUID()
    let role: String
    let content: String
    let timestamp = Date()
}

struct MemoryItem: Identifiable {
    let id = UUID()
    let content: String
    let type: MemoryType
    let timestamp = Date()
    var importance: Double = 0.5
}

enum MemoryType: String {
    case general = "General"
    case task = "Task"
    case fact = "Fact"
    case code = "Code"
    case error = "Error"
    case user = "User"
}
