//
//  ScenarioModels.swift
//  CodeTunner
//
//  Automation Scenario Models - like make.com / n8n
//  Copyright © 2025 SPU AI CLUB. All rights reserved.
//

import SwiftUI
import Foundation

// MARK: - Scenario Model

class ScenarioModel: ObservableObject, Identifiable {
    let id = UUID()
    @Published var name: String
    @Published var nodes: [ScenarioNode] = []
    @Published var connections: [ScenarioConnection] = []
    @Published var isRunning: Bool = false
    @Published var lastRunDate: Date?
    @Published var runCount: Int = 0
    
    init(name: String) {
        self.name = name
    }
}

// MARK: - Node Types

enum ScenarioNodeType: String, CaseIterable, Identifiable, Codable {
    // Triggers
    case trigger = "Trigger"
    case schedule = "Schedule"
    case webhook = "Webhook"
    
    // Communication
    case email = "Email"
    case line = "LINE"
    case telegram = "Telegram"
    case slack = "Slack"
    case discord = "Discord"
    case sms = "SMS"
    case whatsapp = "WhatsApp"
    
    // HTTP & Data
    case http = "HTTP"
    case transform = "Transform"
    case code = "Code"
    case broadcast = "Broadcast"
    case database = "Database"
    case filter = "Filter"
    case delay = "Delay"
    
    // AI Providers (6 providers)
    case openai = "ChatGPT"
    case gemini = "Gemini"
    case claude = "Claude"
    case deepseek = "DeepSeek"
    case glm = "GLM-4"
    case perplexity = "Perplexity"
    
    // Integrations
    case notion = "Notion"
    case googleSheets = "Google Sheets"
    case awsS3 = "AWS S3"
    case firebase = "Firebase"
    case airtable = "Airtable"
    case stripe = "Stripe"
    case container = "Container"
    
    // Flow Control
    case ifCondition = "IF"
    case loop = "Loop"
    case merge = "Merge"
    case variable = "Variable"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .trigger: return "play.circle.fill"
        case .schedule: return "clock.fill"
        case .webhook: return "antenna.radiowaves.left.and.right"
        case .email: return "envelope.fill"
        case .line: return "message.fill"
        case .http: return "globe"
        case .transform: return "gearshape.2.fill"
        case .code: return "chevron.left.forwardslash.chevron.right"
        case .broadcast: return "megaphone.fill"
        case .database: return "cylinder.fill"
        case .filter: return "slider.horizontal.3"
        case .delay: return "timer"
        case .slack: return "number.square.fill"
        case .discord: return "bubble.left.and.bubble.right.fill"
        case .sms: return "phone.fill"
        case .whatsapp: return "phone.circle.fill"
        case .telegram: return "paperplane.fill"
        
        // AI
        case .openai, .gemini, .claude, .deepseek, .glm, .perplexity: return "brain.head.profile"
            
        // Integrations
        case .notion: return "doc.text.fill"
        case .googleSheets: return "tablecells.fill"
        case .awsS3: return "server.rack"
        case .firebase: return "flame.fill"
        case .airtable: return "square.stack.3d.up.fill"
        case .stripe: return "creditcard.fill"
        case .container: return "shippingbox.fill"
            
        // Flow
        case .ifCondition: return "arrow.triangle.branch"
        case .loop: return "repeat"
        case .merge: return "arrow.triangle.merge"
        case .variable: return "x.squareroot"
        }
    }
    
    var color: Color {
        switch self {
        case .trigger, .schedule, .webhook: return .green
        case .email: return .blue
        case .line, .whatsapp: return .green
        case .telegram: return .blue
        case .slack: return .purple
        case .discord: return .indigo
        case .sms: return .teal
            
        case .http: return .orange
        case .transform, .filter, .variable: return .purple
        case .code: return .pink
        case .broadcast: return .red
        
        // AI
        case .openai: return .green
        case .gemini: return .blue
        case .claude: return .orange
        case .deepseek: return .blue
        case .glm: return .purple
        case .perplexity: return .teal
            
        // Integrations
        case .database, .awsS3, .firebase: return .cyan
        case .notion: return .primary
        case .googleSheets: return .green
        case .airtable: return .yellow
        case .stripe: return .indigo
        case .container: return .orange
            
        case .delay, .ifCondition, .loop, .merge: return .gray
        }
    }
    
    var category: NodeCategory {
        switch self {
        case .trigger, .schedule, .webhook: return .triggers
        case .email, .line, .slack, .discord, .broadcast, .sms, .whatsapp, .telegram: return .messaging
        case .http, .notion, .googleSheets, .awsS3, .firebase, .airtable, .stripe, .container: return .integrations
        case .openai, .gemini, .claude, .deepseek, .glm, .perplexity: return .integrations
        case .transform, .filter, .code, .variable: return .logic
        case .database: return .data
        case .delay, .ifCondition, .loop, .merge: return .flow
        }
    }
    
    static var byCategory: [NodeCategory: [ScenarioNodeType]] {
        Dictionary(grouping: allCases, by: { $0.category })
    }
}

enum NodeCategory: String, CaseIterable {
    case triggers = "Triggers"
    case messaging = "Messaging"
    case integrations = "Integrations"
    case logic = "Logic"
    case data = "Data"
    case flow = "Flow Control"
    
    var icon: String {
        switch self {
        case .triggers: return "bolt.fill"
        case .messaging: return "bubble.left.and.bubble.right.fill"
        case .integrations: return "link"
        case .logic: return "gearshape.fill"
        case .data: return "cylinder.fill"
        case .flow: return "arrow.triangle.branch"
        }
    }
}

// MARK: - Scenario Node

class ScenarioNode: ObservableObject, Identifiable {
    let id = UUID()
    @Published var type: ScenarioNodeType
    @Published var name: String
    @Published var position: CGPoint
    @Published var config: NodeConfig
    @Published var isSelected: Bool = false
    @Published var lastOutput: String = ""
    @Published var hasError: Bool = false
    
    init(type: ScenarioNodeType, position: CGPoint) {
        self.type = type
        self.name = type.rawValue
        self.position = position
        self.config = NodeConfig(type: type)
    }
}

// MARK: - Node Config

    struct NodeExecutionResult: Decodable {
        let nodeId: String
        let success: Bool
        // let output: AnyCodable? // difficult to decode arbitrary JSON in Swift perfectly without wrapper
    }


// MARK: - Node Config

struct NodeConfig: Codable {
    var type: ScenarioNodeType
    
    // Common
    var enabled: Bool = true
    
    // Email (Gmail, Outlook, Custom SMTP)
    var emailTo: String = ""
    var emailSubject: String = ""
    var emailBody: String = ""
    var emailAttachmentPath: String = ""
    var smtpHost: String = ""
    var smtpPort: Int = 587
    var smtpUser: String = ""
    var smtpPassword: String = ""
    var emailUseSSL: Bool = true
    
    // LINE Messaging API
    var lineMessageType: String = "push"
    var lineChannelToken: String = ""
    var lineNotifyToken: String = ""
    var lineUserId: String = ""
    var lineGroupId: String = ""
    var lineMessage: String = ""
    var lineImageUrl: String = ""
    var lineStickerPackageId: String = ""
    var lineStickerId: String = ""
    
    // Telegram Bot API
    var telegramBotToken: String = ""
    var telegramChatId: String = ""
    var telegramMessage: String = ""
    var telegramImageUrl: String = ""
    var telegramParseMode: String = "HTML"
    
    // HTTP
    var httpUrl: String = ""
    var httpMethod: String = "GET"
    var httpHeaders: [String: String] = [:]
    var httpBody: String = ""
    var httpTimeout: Int = 30
    
    // Code
    var codeLanguage: String = "python"
    var codeContent: String = ""
    
    // Schedule
    var scheduleInterval: Int = 60
    var scheduleCron: String = ""
    
    // Webhook
    var webhookPath: String = "/webhook"
    
    // Transform
    var transformExpression: String = ""
    
    // Filter
    var filterCondition: String = ""
    
    // Delay
    var delaySeconds: Int = 5
    
    // Database
    var dbType: String = "sqlite"
    var dbConnection: String = ""
    var dbQuery: String = ""
    
    // Broadcast
    var broadcastMessage: String = ""
    
    // AI
    var aiProvider: String = "chatgpt"
    var aiApiKey: String = ""
    var aiModel: String = "gpt-4"
    var aiPrompt: String = ""
    var aiSystemPrompt: String = ""
    var aiTemperature: Double = 0.7
    var aiMaxTokens: Int = 1024
    
    // Provider Specific Keys
    var geminiApiKey: String = ""
    var openaiApiKey: String = ""
    var deepseekApiKey: String = ""
    var glmApiKey: String = ""
    var perplexityApiKey: String = ""
    var claudeApiKey: String = ""
    
    // Google Sheets
    var sheetsSpreadsheetId: String = ""
    var sheetsRange: String = ""
    var sheetsAction: String = "read"
    var sheetsServiceAccountJson: String = ""
    
    init(type: ScenarioNodeType) {
        self.type = type
        
        // Set defaults
        switch type {
        case .code:
            codeContent = "# Your code here\nprint('Hello from Scenario!')"
        case .http:
            httpUrl = "https://api.example.com"
        case .email:
            emailSubject = "Notification"
            emailBody = "This is an automated message."
        case .line:
            lineMessage = "Hello from CodeTunner!"
        default:
            break
        }
    }
}


// MARK: - Scenario Connection

struct ScenarioConnection: Identifiable {
    let id = UUID()
    let sourceNodeId: UUID
    let targetNodeId: UUID
    var label: String = ""
}

// MARK: - Scenario Manager

@MainActor
class ScenarioManager: ObservableObject {
    static let shared = ScenarioManager()
    
    @Published var scenarios: [ScenarioModel] = []
    @Published var activeScenario: ScenarioModel?
    @Published var isRunning: Bool = false
    @Published var logs: [ScenarioLog] = []
    
    private init() {
        // Create default scenario
        let defaultScenario = ScenarioModel(name: "My First Scenario")
        scenarios.append(defaultScenario)
        activeScenario = defaultScenario
    }
    
    func createScenario(name: String) -> ScenarioModel {
        let scenario = ScenarioModel(name: name)
        scenarios.append(scenario)
        return scenario
    }
    
    func deleteScenario(_ scenario: ScenarioModel) {
        scenarios.removeAll { $0.id == scenario.id }
        if activeScenario?.id == scenario.id {
            activeScenario = scenarios.first
        }
    }
    
    func addNode(type: ScenarioNodeType, at position: CGPoint) {
        guard let scenario = activeScenario else { return }
        let node = ScenarioNode(type: type, position: position)
        scenario.nodes.append(node)
    }
    
    func removeNode(_ node: ScenarioNode) {
        guard let scenario = activeScenario else { return }
        scenario.nodes.removeAll { $0.id == node.id }
        scenario.connections.removeAll { $0.sourceNodeId == node.id || $0.targetNodeId == node.id }
    }
    
    func connect(from source: ScenarioNode, to target: ScenarioNode) {
        guard let scenario = activeScenario else { return }
        let connection = ScenarioConnection(sourceNodeId: source.id, targetNodeId: target.id)
        scenario.connections.append(connection)
    }
    
    func disconnect(_ connection: ScenarioConnection) {
        guard let scenario = activeScenario else { return }
        scenario.connections.removeAll { $0.id == connection.id }
    }
    
    // MARK: - Execution
    
    func runScenario() async {
        guard let scenario = activeScenario else { return }
        
        isRunning = true
        scenario.isRunning = true
        addLog("🚀 Starting scenario: \(scenario.name)...")
        
        // Prepare DTO
        let nodesDTO = scenario.nodes.map { node in
            ScenarioNodeDTO(
                id: node.id.uuidString,
                nodeType: node.type.rawValue, // or lowercase? Rust expects string match
                name: node.name,
                config: node.config
            )
        }
        
        let connectionsDTO = scenario.connections.map { conn in
            ScenarioConnectionDTO(
                id: conn.id.uuidString,
                sourceNodeId: conn.sourceNodeId.uuidString,
                targetNodeId: conn.targetNodeId.uuidString
            )
        }
        
        let request = ScenarioExecuteRequest(
            id: scenario.id.uuidString,
            name: scenario.name,
            nodes: nodesDTO,
            connections: connectionsDTO
        )
        
        // Send to Backend
        do {
            let url = URL(string: "http://localhost:3000/api/scenario/execute")!
            var urlRequest = URLRequest(url: url)
            urlRequest.httpMethod = "POST"
            urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            let encoder = JSONEncoder()
            encoder.keyEncodingStrategy = .convertToSnakeCase
            urlRequest.httpBody = try encoder.encode(request)
            
            let (data, response) = try await URLSession.shared.data(for: urlRequest)
            
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                let errorMsg = String(data: data, encoding: .utf8) ?? "Unknown error"
                addLog("❌ Backend execution failed: \(errorMsg)")
                isRunning = false
                scenario.isRunning = false
                return
            }
            
            // decode result
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                let executionResult = try decoder.decode(ScenarioExecutionResult.self, from: data)
                
                // Update UI with logs and results
                DispatchQueue.main.async {
                    self.logs = executionResult.logs.map { ScenarioLog(timestamp: Date(), message: $0) }
                    
                    // Update last output for nodes
                    for nodeResult in executionResult.nodeResults {
                        if let node = scenario.nodes.first(where: { $0.id.uuidString == nodeResult.nodeId }) {
                            node.hasError = !nodeResult.success
                            // node.lastOutput = nodeResult.output // Need to handle AnyCodable
                            if let output = nodeResult.output {
                                node.lastOutput = self.jsonString(from: output)
                            }
                        }
                    }
                    
                    self.isRunning = false
                    scenario.isRunning = false
                    self.addLog(executionResult.success ? "✅ Scenario completed successfully" : "❌ Scenario failed")
                }
                
            } catch {
                DispatchQueue.main.async {
                    self.addLog("❌ API Error: \(error.localizedDescription)")
                    self.isRunning = false
                    scenario.isRunning = false
                }
            }
        }

    
    func executeSingleNode(_ node: ScenarioNode) async {
        addLog("▶️ Testing node: \(node.name)...")
        
        let nodeDTO = ScenarioNodeDTO(
            id: node.id.uuidString,
            nodeType: node.type.rawValue,
            name: node.name,
            config: node.config
        )
        
        // Mock input for testing (empty or previous node result?)
        // For simple testing, we send empty input, or the user might want to provide input JSON in the future.
        // For now, let's assume empty input for standalone test.
        _ = [String: AnyCodable]() 
        
        _ = [
            "node": try! JSONEncoder().encode(nodeDTO), // This will be nested JSON string? No, allow Encodable
             // Rust expects a body with node and input... wait, let's check Rust handler.
             "input": [String: AnyCodable]()
        ] as [String : Any]// Actually, let's check Rust endpoint structure. 
        // Rust: axum::Json(payload): axum::Json<ExecuteNodeRequest>
        // struct ExecuteNodeRequest { node: ScenarioNode, input: Option<serde_json::Value> }
        
        struct ExecuteNodeRequest: Encodable {
            let node: ScenarioNodeDTO
            let input: AnyCodable?
        }
        
        let requestPayload = ExecuteNodeRequest(node: nodeDTO, input: nil)
        
        do {
            let url = URL(string: "http://localhost:3000/api/scenario/node/execute")!
            var urlRequest = URLRequest(url: url)
            urlRequest.httpMethod = "POST"
            urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            let encoder = JSONEncoder()
            encoder.keyEncodingStrategy = .convertToSnakeCase
            urlRequest.httpBody = try encoder.encode(requestPayload)
            
            let (data, response) = try await URLSession.shared.data(for: urlRequest)
            
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                let errorMsg = String(data: data, encoding: .utf8) ?? "Unknown error"
                DispatchQueue.main.async { self.addLog("❌ Test failed: \(errorMsg)") }
                return
            }
            
            // Decode ExecutionResult (Rust: ExecutionResult)
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let result = try decoder.decode(NodeExecutionResult.self, from: data)
            
            DispatchQueue.main.async {
                node.hasError = !result.success
                if let output = result.output {
                    let outputStr = self.jsonString(from: output)
                    node.lastOutput = outputStr
                    self.addLog(outputStr)
                }
                self.addLog(result.success ? "✅ Test passed" : "❌ Test failed: \(result.error ?? "")")
            }
            
        } catch {
            DispatchQueue.main.async {
                self.addLog("❌ Error: \(error.localizedDescription)")
            }
        }
    }
    
    private func jsonString(from anyCodable: AnyCodable) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        if let data = try? encoder.encode(anyCodable), let str = String(data: data, encoding: .utf8) {
            return str
        }
        return "\(anyCodable.value)"
    }
    
    // MARK: - DTOs
    
    struct ScenarioExecuteRequest: Encodable {
        let id: String
        let name: String
        let nodes: [ScenarioNodeDTO]
        let connections: [ScenarioConnectionDTO]
    }
    
    struct ScenarioNodeDTO: Encodable {
        let id: String
        let nodeType: String
        let name: String
        let config: NodeConfig
        
        enum CodingKeys: String, CodingKey {
            case id, nodeType, name, config
        }
    }
    
    struct ScenarioConnectionDTO: Encodable {
        let id: String
        let sourceNodeId: String
        let targetNodeId: String
    }
    
    struct ScenarioExecutionResult: Decodable {
        let success: Bool
        let logs: [String]
        let nodeResults: [NodeExecutionResult]
    }
    
    struct NodeExecutionResult: Decodable {
        let nodeId: String
        let success: Bool
        let output: AnyCodable?
        let error: String?
    }
    
    // MARK: - Logging
    

    public func addLog(_ message: String) {
        let log = ScenarioLog(message: message)
        logs.insert(log, at: 0)
        
        // Keep only last 100 logs
        if logs.count > 100 {
            logs = Array(logs.prefix(100))
        }
    }
    
    public func clearLogs() {
        logs.removeAll()
    }
}

// MARK: - Scenario Log

struct ScenarioLog: Identifiable {
    let id = UUID()
    var timestamp = Date()
    let message: String
}

// MARK: - Errors



// MARK: - AnyCodable


