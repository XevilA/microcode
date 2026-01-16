//
//  AIAgentView.swift
//  CodeTunner
//
//  Production AI Agent with BMAD-METHOD support
//  Build More, Architect Dreams - 4-Phase Methodology
//

import SwiftUI
import Combine
import CodeTunnerSupport

// MARK: - BMAD Agent Roles

enum BMadAgentRole: String, CaseIterable, Identifiable {
    case pm = "PM"
    case architect = "Architect"
    case developer = "Developer"
    case uxDesigner = "UX Designer"
    case qa = "QA Engineer"
    case devops = "DevOps"
    case analyst = "Analyst"
    case docWriter = "Doc Writer"
    case reviewer = "Reviewer"
    case mentor = "Mentor"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .pm: return "person.badge.clock"
        case .architect: return "building.2"
        case .developer: return "chevron.left.forwardslash.chevron.right"
        case .uxDesigner: return "paintbrush"
        case .qa: return "checkmark.shield"
        case .devops: return "gearshape.2"
        case .analyst: return "chart.bar.xaxis"
        case .docWriter: return "doc.text"
        case .reviewer: return "eye"
        case .mentor: return "graduationcap"
        }
    }
    
    var color: Color {
        switch self {
        case .pm: return .blue
        case .architect: return .purple
        case .developer: return .green
        case .uxDesigner: return .pink
        case .qa: return .orange
        case .devops: return .cyan
        case .analyst: return .indigo
        case .docWriter: return .mint
        case .reviewer: return .yellow
        case .mentor: return .teal
        }
    }
    
    var description: String {
        switch self {
        case .pm: return "Requirements, PRD, user stories"
        case .architect: return "System design, tech stack"
        case .developer: return "Code implementation"
        case .uxDesigner: return "Interface design, wireframes"
        case .qa: return "Testing strategy, test cases"
        case .devops: return "CI/CD, deployment"
        case .analyst: return "Research, analysis"
        case .docWriter: return "Technical documentation"
        case .reviewer: return "Code review, best practices"
        case .mentor: return "Guidance, coaching"
        }
    }
    
    var systemPrompt: String {
        switch self {
        case .pm:
            return """
            You are an expert Product Manager AI. Your focus is on:
            - Understanding user needs and requirements
            - Creating clear PRDs (Product Requirement Documents)
            - Writing user stories with acceptance criteria
            - Prioritizing features based on value
            - Stakeholder communication
            Speak in terms of user value and business impact.
            """
        case .architect:
            return """
            You are a Senior Solution Architect AI. Your expertise includes:
            - System design and architecture patterns
            - Technology stack selection
            - Scalability and performance planning
            - API design and integration strategies
            - Security architecture
            Provide architectural diagrams and technical specifications.
            """
        case .developer:
            return """
            You are a Senior Software Developer AI. Your skills include:
            - Writing clean, maintainable code
            - Following best practices and design patterns
            - Implementing features efficiently
            - Debugging and problem-solving
            - Code optimization
            Focus on practical implementation with working code.
            """
        case .uxDesigner:
            return """
            You are a UX/UI Designer AI. Your expertise covers:
            - User experience design principles
            - Interface wireframing and mockups
            - User flow design
            - Accessibility considerations
            - Design system creation
            Think user-first and prioritize usability.
            """
        case .qa:
            return """
            You are a QA Engineer AI. Your focus is on:
            - Test strategy and planning
            - Writing test cases and scenarios
            - Automated testing approaches
            - Bug identification and reporting
            - Quality assurance processes
            Ensure comprehensive coverage and reliability.
            """
        case .devops:
            return """
            You are a DevOps Engineer AI. Your expertise includes:
            - CI/CD pipeline design
            - Infrastructure as Code
            - Containerization (Docker, Kubernetes)
            - Monitoring and observability
            - Deployment strategies
            Focus on automation and reliability.
            """
        case .analyst:
            return """
            You are a Business Analyst AI. Your skills include:
            - Market research and analysis
            - Competitive analysis
            - Data analysis and insights
            - Requirements gathering
            - ROI analysis
            Provide data-driven recommendations.
            """
        case .docWriter:
            return """
            You are a Technical Writer AI. Your expertise covers:
            - API documentation
            - User guides and tutorials
            - README creation
            - Code comments and documentation
            - Knowledge base articles
            Write clear, comprehensive documentation.
            """
        case .reviewer:
            return """
            You are a Code Reviewer AI. Your focus is on:
            - Code quality assessment
            - Best practices enforcement
            - Security vulnerability detection
            - Performance optimization suggestions
            - Maintainability improvements
            Provide constructive, actionable feedback.
            """
        case .mentor:
            return """
            You are an AI Mentor. Your role is to:
            - Guide developers through challenges
            - Explain concepts clearly
            - Suggest learning resources
            - Encourage best practices
            - Provide career development advice
            Be supportive, educational, and encouraging.
            """
        }
    }
}

// MARK: - BMAD Phases

enum BMadPhase: String, CaseIterable, Identifiable {
    case analysis = "Analysis"
    case planning = "Planning"
    case solutioning = "Solutioning"
    case implementation = "Implementation"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .analysis: return "📊"
        case .planning: return "📝"
        case .solutioning: return "🏗️"
        case .implementation: return "⚡"
        }
    }
    
    var description: String {
        switch self {
        case .analysis: return "Research, brainstorm, explore"
        case .planning: return "PRD, specs, requirements"
        case .solutioning: return "Architecture, UX design"
        case .implementation: return "Code development"
        }
    }
    
    var suggestedAgents: [BMadAgentRole] {
        switch self {
        case .analysis: return [.analyst, .pm, .mentor]
        case .planning: return [.pm, .architect, .uxDesigner]
        case .solutioning: return [.architect, .uxDesigner, .devops]
        case .implementation: return [.developer, .qa, .reviewer]
        }
    }
}

// MARK: - Agent Service

@MainActor
class AgentService: ObservableObject {
    static let shared = AgentService()
    
    @Published var sessionId: String?
    @Published var messages: [AgentMessageModel] = []
    @Published var isLoading = false
    @Published var context: ProjectContextModel?
    @Published var tools: [ToolDefinitionModel] = []
    @Published var pendingChanges: [PendingChangeModel] = []
    @Published var editorContext: EditorContextModel?
    @Published var ragStatus: RagIndexStatusModel?
    
    // BMAD Agent State
    @Published var selectedAgent: BMadAgentRole = .developer
    @Published var selectedPhase: BMadPhase = .implementation
    
    private let baseURL = "http://127.0.0.1:3000"
    private(set) var workspacePath: String?
    
    func createSession(workspacePath: String) async {
        isLoading = true
        defer { isLoading = false }
        
        guard let url = URL(string: "\(baseURL)/api/agent/session/create") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = ["workspace_path": workspacePath]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let sid = json["session_id"] as? String {
                sessionId = sid
                self.workspacePath = workspacePath
                await fetchContext()
                await fetchTools()
                await startIndexing()
            }
        } catch {
            print("Failed to create session: \(error)")
        }
    }
    
    func fetchContext() async {
        guard let sid = sessionId else { return }
        guard let url = URL(string: "\(baseURL)/api/agent/context/\(sid)") else { return }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            context = try? JSONDecoder().decode(ProjectContextModel.self, from: data)
        } catch {
            print("Failed to fetch context: \(error)")
        }
    }
    
    func fetchTools() async {
        guard let url = URL(string: "\(baseURL)/api/agent/tools") else { return }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let json = try? JSONDecoder().decode([String: [ToolDefinitionModel]].self, from: data),
               let t = json["tools"] {
                tools = t
            }
        } catch {
            print("Failed to fetch tools: \(error)")
        }
    }

    func fetchIndexStatus() async {
        guard let url = URL(string: "\(baseURL)/api/agent/index/status") else { return }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            ragStatus = try? JSONDecoder().decode(RagIndexStatusModel.self, from: data)
        } catch {
            print("Failed to fetch index status: \(error)")
        }
    }

    func startIndexing() async {
        guard let workspacePath else { return }
        guard let url = URL(string: "\(baseURL)/api/agent/index/start") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = ["workspace_path": workspacePath]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        do {
            let (_, _) = try await URLSession.shared.data(for: request)
            await fetchIndexStatus()
        } catch {
            print("Failed to start indexing: \(error)")
        }
    }
    
    // MARK: - Production Enhanced Chat
    
    func sendEnhancedMessage(_ content: String, provider: String = "gemini", model: String = "gemini-2.5-flash", apiKey: String = "", autoExecute: Bool = true) async {
        guard let sid = sessionId else { return }
        
        // Add user message immediately
        let userMessage = AgentMessageModel(
            id: UUID().uuidString,
            role: .user,
            content: content,
            toolResults: [],
            pendingChanges: [],
            timestamp: Date()
        )
        messages.append(userMessage)
        
        isLoading = true
        defer { isLoading = false }
        
        guard let url = URL(string: "\(baseURL)/api/agent/enhanced-chat") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Build request with editor context
        var body: [String: Any] = [
            "session_id": sid,
            "message": content,
            "provider": provider,
            "model": model,
            "auto_execute": autoExecute
        ]
        
        if let ctx = editorContext {
            var contextDict: [String: Any] = [
                "active_file": ctx.activeFile as Any,
                "active_content": ctx.activeContent as Any,
                "cursor_line": ctx.cursorLine as Any,
                "cursor_column": ctx.cursorColumn as Any,
                "selected_text": ctx.selectedText as Any,
                "open_files": ctx.openFiles,
                "language": ctx.language as Any
            ]
            
            // Inject AuthenticAIContext (Smart Core)
            if let smartContext = AuthenticLanguageCore.shared().aiContext() {
                contextDict["semantic_context"] = smartContext.llmContextDescription
            }
            
            body["editor_context"] = contextDict
        }
        
        // Add BMAD agent context
        body["agent_role"] = selectedAgent.rawValue
        body["phase"] = selectedPhase.rawValue
        body["system_prompt"] = selectedAgent.systemPrompt
        
        if !apiKey.isEmpty {
            body["api_key"] = apiKey
        }
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                let responseContent = json["content"] as? String ?? ""
                
                var toolResults: [ToolResultModel] = []
                if let results = json["tool_results"] as? [[String: Any]] {
                    for r in results {
                        toolResults.append(ToolResultModel(
                            toolCallId: r["tool_call_id"] as? String ?? "",
                            success: r["success"] as? Bool ?? false,
                            output: r["output"] as? String ?? "",
                            error: r["error"] as? String
                        ))
                    }
                }
                
                var changes: [PendingChangeModel] = []
                if let pending = json["pending_changes"] as? [[String: Any]] {
                    for p in pending {
                        let diff = p["diff"] as? [String: Any]
                        changes.append(PendingChangeModel(
                            id: p["id"] as? String ?? UUID().uuidString,
                            filePath: diff?["file_path"] as? String ?? "",
                            description: p["description"] as? String ?? "",
                            additions: diff?["additions"] as? Int ?? 0,
                            deletions: diff?["deletions"] as? Int ?? 0,
                            oldContent: diff?["old_content"] as? String ?? "",
                            newContent: diff?["new_content"] as? String ?? "",
                            status: .pending
                        ))
                    }
                    pendingChanges.append(contentsOf: changes)
                }
                
                let assistantMessage = AgentMessageModel(
                    id: UUID().uuidString,
                    role: .assistant,
                    content: responseContent,
                    toolResults: toolResults,
                    pendingChanges: changes,
                    timestamp: Date()
                )
                messages.append(assistantMessage)
            }
        } catch {
            let errorMessage = AgentMessageModel(
                id: UUID().uuidString,
                role: .assistant,
                content: "Error: \(error.localizedDescription)",
                toolResults: [],
                pendingChanges: [],
                timestamp: Date()
            )
            messages.append(errorMessage)
        }
    }
    
    // Legacy chat for compatibility
    func sendMessage(_ content: String, provider: String = "gemini", model: String = "gemini-2.5-flash", apiKey: String = "") async {
        await sendEnhancedMessage(content, provider: provider, model: model, apiKey: apiKey, autoExecute: true)
    }
    
    // MARK: - Pending Changes
    
    func applyChange(_ changeId: String) async {
        guard let url = URL(string: "\(baseURL)/api/agent/apply-change/\(changeId)") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let success = json["success"] as? Bool, success {
                if let idx = pendingChanges.firstIndex(where: { $0.id == changeId }) {
                    pendingChanges[idx].status = .accepted
                }
                let msg = AgentMessageModel(
                    id: UUID().uuidString,
                    role: .system,
                    content: "✅ Applied changes",
                    toolResults: [],
                    pendingChanges: [],
                    timestamp: Date()
                )
                messages.append(msg)
            }
        } catch {
            print("Apply change failed: \(error)")
        }
    }
    
    func rejectChange(_ changeId: String) async {
        guard let url = URL(string: "\(baseURL)/api/agent/reject-change/\(changeId)") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        do {
            let (_, _) = try await URLSession.shared.data(for: request)
            if let idx = pendingChanges.firstIndex(where: { $0.id == changeId }) {
                pendingChanges[idx].status = .rejected
            }
        } catch {
            print("Reject change failed: \(error)")
        }
    }
    
    func executeTool(name: String, arguments: [String: Any]) async {
        guard let sid = sessionId else { return }
        guard let url = URL(string: "\(baseURL)/api/agent/tool/execute") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "session_id": sid,
            "tool_name": name,
            "arguments": arguments
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                let output = json["output"] as? String ?? "Tool executed"
                let success = json["success"] as? Bool ?? false
                
                let msg = AgentMessageModel(
                    id: UUID().uuidString,
                    role: .tool,
                    content: success ? "✅ \(name): \(output)" : "❌ \(name) failed",
                    toolResults: [],
                    pendingChanges: [],
                    timestamp: Date()
                )
                messages.append(msg)
            }
        } catch {
            print("Tool execution failed: \(error)")
        }
    }
    
    func undo() async {
        guard let sid = sessionId else { return }
        guard let url = URL(string: "\(baseURL)/api/agent/undo/\(sid)") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let message = json["message"] as? String {
                let msg = AgentMessageModel(
                    id: UUID().uuidString,
                    role: .system,
                    content: "↩️ Undo: \(message)",
                    toolResults: [],
                    pendingChanges: [],
                    timestamp: Date()
                )
                messages.append(msg)
            }
        } catch {
            print("Undo failed: \(error)")
        }
    }
    
    // MARK: - Editor Context Update
    func updateEditorContext(activeFile: String?, content: String?, cursorLine: Int?, selectedText: String?, openFiles: [String] = [], language: String? = nil) {
        editorContext = EditorContextModel(
            activeFile: activeFile,
            activeContent: content,
            cursorLine: cursorLine,
            cursorColumn: nil,
            selectedText: selectedText,
            openFiles: openFiles,
            language: language
        )
    }
}

// MARK: - Models

struct AgentMessageModel: Identifiable {
    let id: String
    let role: MessageRole
    let content: String
    let toolResults: [ToolResultModel]
    let pendingChanges: [PendingChangeModel]
    let timestamp: Date
    
    enum MessageRole: String {
        case user, assistant, system, tool
    }
}

struct ToolResultModel {
    let toolCallId: String
    let success: Bool
    let output: String
    let error: String?
}

// Production Models - Like Cursor/Windsurf

struct PendingChangeModel: Identifiable {
    let id: String
    let filePath: String
    let description: String
    let additions: Int
    let deletions: Int
    let oldContent: String
    let newContent: String
    var status: PendingChangeStatus
    
    enum PendingChangeStatus {
        case pending, accepted, rejected
    }
}

struct EditorContextModel {
    let activeFile: String?
    let activeContent: String?
    let cursorLine: Int?
    let cursorColumn: Int?
    let selectedText: String?
    let openFiles: [String]
    let language: String?
}

struct ProjectContextModel: Codable {
    let root_path: String
    let project_type: String
    let files: [FileInfoModel]?
    let recent_files: [String]?
}

struct FileInfoModel: Codable {
    let path: String
    let relative_path: String
    let size: Int
    let is_directory: Bool
}

struct ToolDefinitionModel: Codable, Identifiable {
    var id: String { name }
    let name: String
    let description: String
}

struct RagIndexStatusModel: Codable {
    let is_indexing: Bool
    let is_ready: Bool
    let last_indexed_at: String?
    let chunk_count: Int
    let error: String?
}

// MARK: - AI Agent View

struct AIAgentView: View {
    @StateObject private var agent = AgentService.shared
    @State private var inputText = ""
    @State private var workspacePath = ""
    @State private var showSettings = false
    @State private var selectedProvider = "gemini"
    @State private var selectedModel = "gemini-3-pro-preview"
    @State private var apiKey = ""
    
    var body: some View {
        CompatHSplitView {
            // Main Chat Area
            VStack(spacing: 0) {
                // Header
                headerView
                
                Divider()
                
                // Messages
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            ForEach(agent.messages) { message in
                                MessageBubble(
                                    message: message,
                                    onApply: { id in await agent.applyChange(id) },
                                    onReject: { id in await agent.rejectChange(id) }
                                )
                                .id(message.id)
                            }
                            
                            if agent.isLoading {
                                HStack {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                    Text("Thinking...")
                                        .foregroundColor(.secondary)
                                }
                                .padding()
                            }
                        }
                        .padding()
                    }
                    .onChange(of: agent.messages.count) { _ in
                        if let lastId = agent.messages.last?.id {
                            withAnimation {
                                proxy.scrollTo(lastId, anchor: .bottom)
                            }
                        }
                    }
                }
                
                Divider()
                
                // Input Area
                inputView
            }
            .frame(minWidth: 500)
            
            // Sidebar
            sidebarView
                .frame(width: 280)
        }
        .onAppear {
            if agent.sessionId == nil && !workspacePath.isEmpty {
                Task { await agent.createSession(workspacePath: workspacePath) }
            }
            Task { await agent.fetchIndexStatus() }
        }
    }
    
    private var headerView: some View {
        VStack(spacing: 0) {
            // Main HUD Header
            HStack {
                // Agent Identity Block
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(colors: [Color(red: 1.0, green: 0.435, blue: 0.0), Color.orange], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 36, height: 36)
                            .shadow(color: .orange.opacity(0.5), radius: 4)
                        
                        Image(systemName: agent.selectedAgent.icon)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(agent.selectedAgent.rawValue.uppercased())
                            .font(.system(size: 14, weight: .heavy, design: .monospaced))
                            .foregroundColor(.white)
                        
                        Text("ACTIVE AGENT // \(agent.selectedAgent.description)")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                
                Spacer()
                
                // Phase Indicator (HUD Style)
                HStack(spacing: 2) {
                    ForEach(BMadPhase.allCases) { phase in
                        Button {
                            agent.selectedPhase = phase
                            if let suggested = phase.suggestedAgents.first {
                                agent.selectedAgent = suggested
                            }
                        } label: {
                            VStack(spacing: 2) {
                                Text(phase.icon)
                                    .font(.caption2)
                                    .opacity(agent.selectedPhase == phase ? 1 : 0.5)
                                
                                Rectangle()
                                    .fill(agent.selectedPhase == phase ? Color(red: 1.0, green: 0.435, blue: 0.0) : Color.white.opacity(0.1))
                                    .frame(width: 30, height: 3)
                            }
                        }
                        .buttonStyle(.plain)
                        .help("\(phase.rawValue): \(phase.description)")
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.black.opacity(0.3))
                .cornerRadius(4)
                
                // Tools Block
                HStack(spacing: 8) {
                    Button(action: { Task { await agent.undo() } }) {
                        Image(systemName: "arrow.uturn.backward")
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: { showSettings.toggle() }) {
                        Image(systemName: "gear")
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $showSettings) {
                        settingsPopover
                    }
                }
                .padding(.leading, 8)
            }
            .padding(12)
            .background(
                LinearGradient(colors: [Color(red: 0.0, green: 0.1, blue: 0.2), Color(red: 0.0, green: 0.2, blue: 0.4)], startPoint: .leading, endPoint: .trailing)
            )
            
            // Agent Selector Track
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(BMadAgentRole.allCases) { role in
                        Button {
                            withAnimation(.spring()) {
                                agent.selectedAgent = role
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: role.icon)
                                    .font(.system(size: 10))
                                Text(role.rawValue.uppercased())
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                agent.selectedAgent == role ?
                                Color(red: 1.0, green: 0.435, blue: 0.0) :
                                Color.white.opacity(0.05)
                            )
                            .foregroundColor(.white)
                            .cornerRadius(4)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .background(Color(red: 0.0, green: 0.05, blue: 0.1))
            
            Divider().background(Color(red: 1.0, green: 0.435, blue: 0.0).opacity(0.3))
        }
    }
    
    private var inputView: some View {
        HStack(spacing: 12) {
            // Workspace selector
            if agent.sessionId == nil {
                HStack {
                    Image(systemName: "folder")
                        .foregroundColor(.gray)
                    TextField("Workspace path", text: $workspacePath)
                        .textFieldStyle(.plain)
                    
                    Button("CONNECT") {
                        Task { await agent.createSession(workspacePath: workspacePath) }
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color(red: 0.0, green: 0.2, blue: 0.4))
                    .cornerRadius(4)
                }
                .padding(12)
                .background(Color.black.opacity(0.3))
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.1), lineWidth: 1))
                .padding()
            } else {
                // Message input
                HStack(spacing: 0) {
                    TextField("Command the AI...", text: $inputText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13, design: .monospaced))
                        .onSubmit { sendMessage() }
                        .padding(12)
                    
                    Button(action: sendMessage) {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.white)
                            .padding(10)
                            .background(Color(red: 1.0, green: 0.435, blue: 0.0))
                            .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                    .padding(4)
                    .disabled(inputText.isEmpty || agent.isLoading)
                    .opacity(inputText.isEmpty ? 0.5 : 1)
                }
                .background(Color.black.opacity(0.3))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(agent.isLoading ? Color(red: 1.0, green: 0.435, blue: 0.0) : Color.white.opacity(0.1), lineWidth: 1)
                )
                .padding()
            }
        }
    }
    
    private var sidebarView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Context Info
            Text("Context")
                .font(.headline)
                .padding()
            
            Divider()
            
            if let ctx = agent.context {
                List {
                    Section("Project") {
                        Label(ctx.project_type.capitalized, systemImage: "folder.fill")
                        if let files = ctx.files {
                            Label("\(files.count) files indexed", systemImage: "doc.text")
                        }
                    }
                    
                    Section("Recent Files") {
                        if let recent = ctx.recent_files?.prefix(10) {
                            ForEach(Array(recent), id: \.self) { path in
                                let name = (path as NSString).lastPathComponent
                                Label(name, systemImage: "doc")
                                    .font(.caption)
                            }
                        }
                    }
                }
            } else {
                // No context placeholder (macOS 13 compatible)
                VStack(spacing: 12) {
                    Image(systemName: "folder.badge.questionmark")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("No Context")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("Connect to a workspace")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Divider()
            
            vectorDatabaseView
            
            Divider()
            
            // Available Tools
            Text("Tools")
                .font(.headline)
                .padding()
            
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(agent.tools) { tool in
                        HStack {
                            Image(systemName: iconForTool(tool.name))
                                .foregroundColor(.blue)
                            VStack(alignment: .leading) {
                                Text(tool.name)
                                    .font(.caption.bold())
                                Text(tool.description)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .lineLimit(2)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
        }
        .background(Color(NSColor.windowBackgroundColor))
    }

    private var vectorDatabaseView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Vector DB")
                .font(.headline)
                .padding(.horizontal)
                .padding(.top)
            
            HStack(spacing: 8) {
                Circle()
                    .fill(ragStatusColor)
                    .frame(width: 8, height: 8)
                Text(ragStatusText)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal)
            
            if let status = agent.ragStatus {
                VStack(alignment: .leading, spacing: 4) {
                    if let lastIndexed = formattedIndexTime(status.last_indexed_at) {
                        Text("Last indexed: \(lastIndexed)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    Text("Chunks: \(status.chunk_count)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    if let error = status.error {
                        Text(error)
                            .font(.caption2)
                            .foregroundColor(.red)
                            .lineLimit(2)
                    }
                }
                .padding(.horizontal)
            } else {
                Text("No index status yet.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
            }
            
            HStack(spacing: 8) {
                Button(action: { Task { await agent.startIndexing() } }) {
                    Text("Index Now")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                
                Button(action: { Task { await agent.fetchIndexStatus() } }) {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
    }
    
    private var settingsPopover: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("AI Settings")
                .font(.headline)
            
            Divider()
            
            Picker("Provider", selection: $selectedProvider) {
                Text("Gemini").tag("gemini")
                Text("OpenAI").tag("openai")
                Text("Claude").tag("anthropic")
                Text("DeepSeek").tag("deepseek")
            }
            
            TextField("Model", text: $selectedModel)
                .textFieldStyle(.roundedBorder)
            
            SecureField("API Key (optional)", text: $apiKey)
                .textFieldStyle(.roundedBorder)
        }
        .padding()
        .frame(width: 250)
    }
    
    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        inputText = ""
        
        Task {
            await agent.sendMessage(text, provider: selectedProvider, model: selectedModel, apiKey: apiKey)
        }
    }
    
    private func iconForTool(_ name: String) -> String {
        switch name {
        case "read_file": return "doc.text"
        case "write_file": return "doc.badge.plus"
        case "edit_file": return "pencil"
        case "delete_file": return "trash"
        case "list_directory": return "folder"
        case "search_code": return "magnifyingglass"
        case "create_task": return "checkmark.circle"
        case "run_command": return "terminal"
        case "git_status": return "arrow.triangle.branch"
        case "git_commit": return "checkmark.seal"
        case "search_rag": return "database"
        default: return "wrench"
        }
    }

    private var ragStatusColor: Color {
        if let status = agent.ragStatus {
            if status.error != nil {
                return .red
            }
            if status.is_indexing {
                return .orange
            }
            if status.is_ready {
                return .green
            }
        }
        return .gray
    }

    private var ragStatusText: String {
        if let status = agent.ragStatus {
            if status.is_indexing {
                return "Indexing..."
            }
            if status.is_ready {
                return "Ready"
            }
            if status.error != nil {
                return "Error"
            }
        }
        return "Idle"
    }

    private func formattedIndexTime(_ timestamp: String?) -> String? {
        guard let timestamp else { return nil }
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: timestamp) else { return timestamp }
        let displayFormatter = DateFormatter()
        displayFormatter.dateStyle = .medium
        displayFormatter.timeStyle = .short
        return displayFormatter.string(from: date)
    }
}

// MARK: - Message Bubble

struct MessageBubble: View {
    let message: AgentMessageModel
    var onApply: (String) async -> Void = { _ in }
    var onReject: (String) async -> Void = { _ in }
    
    @State private var isReasoningExpanded = false
    
    // Theme Colors
    private let deepBlue = Color(red: 0.0, green: 0.2, blue: 0.4)
    private let safetyOrange = Color(red: 1.0, green: 0.435, blue: 0.0)
    
    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            // Margin / Timeline Line
            ZStack {
                Rectangle()
                    .fill(Color(white: 0.15))
                    .frame(width: 2)
                
                Circle()
                    .fill(avatarColor)
                    .frame(width: 24, height: 24)
                    .overlay(
                        Image(systemName: avatarIcon)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.black)
                    )
                    .background(Circle().stroke(Color(white: 0.1), lineWidth: 4))
            }
            .frame(width: 40)
            
            // Content Block
            VStack(alignment: .leading, spacing: 8) {
                // Header
                HStack {
                    Text(roleName.uppercased())
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(avatarColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(avatarColor.opacity(0.1))
                        .cornerRadius(4)
                    
                    if message.role != .user {
                        Text(message.timestamp, style: .time)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                }
                .padding(.top, 4)
                
                // Reasoning / Tool Logs (Collapsible)
                if !message.toolResults.isEmpty {
                    DisclosureGroup(
                        isExpanded: $isReasoningExpanded,
                        content: {
                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(message.toolResults, id: \.toolCallId) { result in
                                    HStack(alignment: .top) {
                                        Text(result.success ? "PASSED" : "FAILED")
                                            .font(.system(size: 9, weight: .bold))
                                            .foregroundColor(result.success ? .green : .red)
                                            .frame(width: 45, alignment: .leading)
                                        
                                        Text(result.output)
                                            .font(.system(size: 10, design: .monospaced))
                                            .foregroundColor(.gray)
                                    }
                                    .padding(4)
                                    .background(Color.black.opacity(0.2))
                                    .cornerRadius(4)
                                }
                            }
                            .padding(.top, 4)
                        },
                        label: {
                            HStack {
                                Image(systemName: "cpu")
                                Text("SYSTEM LOGS (\(message.toolResults.count))")
                            }
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(.gray)
                        }
                    )
                }
                
                // Main Content
                if !message.content.isEmpty {
                    Text(message.content)
                        .font(message.role == .user ? .body : .system(.body, design: .monospaced))
                        .foregroundColor(message.role == .user ? .white : .primary)
                        .padding(message.role == .user ? 12 : 0)
                        .background(message.role == .user ? deepBlue.opacity(0.8) : Color.clear)
                        .cornerRadius(message.role == .user ? 12 : 0)
                        .textSelection(.enabled)
                }
                
                // Pending Changes - Mission Control Style
                if !message.pendingChanges.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack {
                            Image(systemName: "pencil.and.outline")
                            Text("PROPOSED MODIFICATIONS")
                            Spacer()
                            Text("\(message.pendingChanges.count) FILES")
                        }
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .padding(8)
                        .background(safetyOrange.opacity(0.1))
                        .foregroundColor(safetyOrange)
                        
                        Divider().background(safetyOrange.opacity(0.3))
                        
                        ForEach(message.pendingChanges) { change in
                            PendingChangeCard(change: change, onApply: onApply, onReject: onReject)
                                .padding(8)
                            Divider().background(Color.white.opacity(0.1))
                        }
                    }
                    .background(Color(white: 0.05))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(safetyOrange.opacity(0.3), lineWidth: 1)
                    )
                    .padding(.top, 4)
                }
            }
            .padding(.bottom, 16)
            .padding(.trailing, 16)
        }
    }
    
    private var avatarColor: Color {
        switch message.role {
        case .user: return .white
        case .assistant: return safetyOrange // Agent is Orange
        case .system: return .purple
        case .tool: return .gray
        }
    }
    
    private var roleName: String {
        switch message.role {
        case .user: return "OPERATOR"
        case .assistant: return "MAJOR" // The Persona Name
        case .system: return "SYSTEM"
        case .tool: return "TOOL"
        }
    }
    
    private var avatarIcon: String {
        switch message.role {
        case .user: return "person.fill"
        case .assistant: return "brain"
        case .system: return "gear"
        case .tool: return "wrench.fill"
        }
    }
}

// MARK: - Pending Change Card (Like Cursor)

struct PendingChangeCard: View {
    let change: PendingChangeModel
    let onApply: (String) async -> Void
    let onReject: (String) async -> Void
    @State private var showDiff = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text((change.filePath as NSString).lastPathComponent)
                        .font(.caption.bold())
                    Text(change.description)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Stats
                HStack(spacing: 8) {
                    Text("+\(change.additions)")
                        .font(.caption.monospaced())
                        .foregroundColor(.green)
                    Text("-\(change.deletions)")
                        .font(.caption.monospaced())
                        .foregroundColor(.red)
                }
            }
            
            // Action buttons
            HStack(spacing: 8) {
                Button("View Diff") {
                    showDiff.toggle()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                if change.status == .pending {
                    Button("Accept") {
                        Task { await onApply(change.id) }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    .controlSize(.small)
                    
                    Button("Reject") {
                        Task { await onReject(change.id) }
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                    .controlSize(.small)
                } else {
                    Text(change.status == .accepted ? "✅ Accepted" : "❌ Rejected")
                        .font(.caption)
                        .foregroundColor(change.status == .accepted ? .green : .red)
                }
            }
            
            if showDiff {
                DiffPreviewView(oldContent: change.oldContent, newContent: change.newContent)
            }
        }
        .padding(8)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(6)
    }
}

// MARK: - Diff Preview View (Like Cursor/Windsurf)

struct DiffPreviewView: View {
    let oldContent: String
    let newContent: String
    
    private var diffLines: [(type: DiffType, content: String)] {
        generateDiff()
    }
    
    enum DiffType {
        case context, addition, deletion
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(diffLines.enumerated()), id: \.offset) { _, line in
                    HStack(spacing: 0) {
                        Text(line.type == .addition ? "+" : (line.type == .deletion ? "-" : " "))
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(lineColor(line.type))
                            .frame(width: 16)
                        
                        Text(line.content)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(lineColor(line.type))
                        
                        Spacer()
                    }
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(lineBackground(line.type))
                }
            }
        }
        .frame(maxHeight: 200)
        .background(Color(NSColor.textBackgroundColor))
        .cornerRadius(4)
    }
    
    private func lineColor(_ type: DiffType) -> Color {
        switch type {
        case .addition: return .green
        case .deletion: return .red
        case .context: return .primary
        }
    }
    
    private func lineBackground(_ type: DiffType) -> Color {
        switch type {
        case .addition: return Color.green.opacity(0.1)
        case .deletion: return Color.red.opacity(0.1)
        case .context: return .clear
        }
    }
    
    private func generateDiff() -> [(type: DiffType, content: String)] {
        let oldLines = oldContent.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let newLines = newContent.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        
        var result: [(type: DiffType, content: String)] = []
        var i = 0, j = 0
        
        while i < oldLines.count || j < newLines.count {
            if i < oldLines.count && j < newLines.count && oldLines[i] == newLines[j] {
                result.append((.context, oldLines[i]))
                i += 1
                j += 1
            } else if i < oldLines.count && (j >= newLines.count || !newLines[j..<min(j+3, newLines.count)].contains(oldLines[i])) {
                result.append((.deletion, oldLines[i]))
                i += 1
            } else if j < newLines.count {
                result.append((.addition, newLines[j]))
                j += 1
            }
        }
        
        return result
    }
}

// MARK: - ReAct Steps View

struct ReActStepsView: View {
    @ObservedObject var executor: AgentExecutor
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Image(systemName: "brain.head.profile")
                    .foregroundColor(.purple)
                Text("ReAct Execution")
                    .font(.headline)
                
                Spacer()
                
                if executor.isRunning {
                    ProgressView(value: executor.progress)
                        .frame(width: 100)
                    
                    Button("Cancel") {
                        executor.cancel()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            
            Divider()
            
            // Steps Timeline
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(executor.steps) { step in
                        ExecutionStepView(step: step)
                    }
                    
                    if executor.isRunning {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Thinking...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                    }
                }
            }
            
            // Final Result
            if let result = executor.finalResult {
                Divider()
                
                VStack(alignment: .leading, spacing: 8) {
                    Label("Final Answer", systemImage: "checkmark.circle.fill")
                        .font(.headline)
                        .foregroundColor(.green)
                    
                    Text(result)
                        .font(.body)
                        .textSelection(.enabled)
                        .padding(12)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(8)
                }
                .padding()
            }
        }
        .background(Color(nsColor: .textBackgroundColor))
        .cornerRadius(12)
    }
}

struct ExecutionStepView: View {
    let step: ExecutionStep
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Step Header
            Button {
                withAnimation { isExpanded.toggle() }
            } label: {
                HStack(spacing: 12) {
                    // Timeline dot
                    Circle()
                        .fill(step.color)
                        .frame(width: 10, height: 10)
                    
                    // Icon
                    Image(systemName: step.icon)
                        .foregroundColor(step.color)
                        .frame(width: 20)
                    
                    // Title
                    Text(step.title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(step.color.opacity(0.05))
            }
            .buttonStyle(.plain)
            
            // Step Content (expanded)
            if isExpanded {
                Text(step.content)
                    .font(.system(size: 12, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(nsColor: .textBackgroundColor))
            }
            
            // Timeline line
            HStack {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 2, height: 20)
                    .padding(.leading, 19)
                Spacer()
            }
        }
    }
}

// MARK: - Agent Execution Panel

struct AgentExecutionPanel: View {
    @StateObject private var executor = AgentExecutor.shared
    @State private var task: String = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Task Input
            HStack {
                TextField("Enter task for agent...", text: $task)
                    .textFieldStyle(.roundedBorder)
                
                Button("Run Agent") {
                    Task {
                        _ = try? await executor.run(task: task)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(task.isEmpty || executor.isRunning)
            }
            .padding()
            
            Divider()
            
            // ReAct Steps
            ReActStepsView(executor: executor)
        }
    }
}

#Preview {
    AIAgentView()
        .frame(width: 900, height: 600)
}
