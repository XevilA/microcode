//
//  AIAgentView.swift
//  CodeTunner
//
//  Redesigned by MicroCode AI - Professional Edition + Rich Content
//  Industrial/IDE aesthetic. Markdown & Code Block Support.
//

import SwiftUI
import Combine
import CodeTunnerSupport
import AppKit

// MARK: - AI Agent View (Professional)

struct AIAgentView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var agent = AgentService.shared
    
    @State private var inputText = ""
    @State private var attachments: [AIAttachment] = []
    @State private var isHoveringInput = false
    @FocusState private var isInputFocused: Bool
    
    // Aesthetic Constants
    private let borderColor = Color.white.opacity(0.1)
    private let paneColor = Color(nsColor: .controlBackgroundColor)
    private let accentColor = Color.accentColor
    
    var body: some View {
        HStack(spacing: 0) {
            // Chat Sidebar (Collapsible)
            if agent.showChatSidebar {
                chatSidebar
                    .frame(width: 220)
                Divider()
            }
            
            // Main Content
            VStack(spacing: 0) {
                // 1. Toolbar / Header (Solid, Industrial)
                headerBar
                
                Divider().background(borderColor)
                
                // 2. Main Content Area
                ZStack(alignment: .bottom) {
                    // Chat Scroll
                    AgentChatStage(messages: agent.messages, isLoading: agent.isLoading)
                    
                    // Input Container (Docked at bottom, not floating)
                    inputArea
                }
            }
        }
        .background(appState.appTheme == .transparent || appState.appTheme == .extraClear ? Color.clear : Color(nsColor: .windowBackgroundColor))
        .onAppear {
            if agent.sessionId == nil, let workspace = appState.workspaceFolder {
                Task {
                    await agent.createSession(workspacePath: workspace.path)
                }
            }
        }
    }
    
    // MARK: - Chat Sidebar
    
    private var chatSidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("CHATS")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
                Spacer()
                Button(action: { _ = agent.createNewChat() }) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
                .help("New Chat")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            
            Divider()
            
            // Chat List
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(agent.chatSessions) { chat in
                        ChatListRow(
                            chat: chat,
                            isActive: agent.activeChatId == chat.id,
                            onSelect: { agent.switchChat(to: chat.id) },
                            onDelete: { agent.deleteChat(chat.id) }
                        )
                    }
                }
                .padding(8)
            }
        }
        .background(paneColor.opacity(0.5))
    }
    
    // MARK: - Header Bar
    
    private var headerBar: some View {
        HStack(spacing: 0) {
            // Sidebar Toggle
            Button(action: { agent.showChatSidebar.toggle() }) {
                Image(systemName: "sidebar.left")
                    .font(.system(size: 12))
                    .foregroundColor(agent.showChatSidebar ? .accentColor : .secondary)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .help("Toggle Chat History")
            
            // New Chat Button
            Button(action: { _ = agent.createNewChat() }) {
                Image(systemName: "plus.message")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("New Chat")
            
            Divider()
                .frame(height: 14)
                .padding(.horizontal, 8)
            
            // Title Tab
            HStack(spacing: 8) {
                Image(systemName: "terminal.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                
                Text("MICROCODE AGENT")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.secondary)
                    .tracking(0.5)
            }
            
            Spacer()
            
            // Actions Toolbar
            HStack(spacing: 0) {
                // Smart Finder
                Menu {
                    Text("Jump to Tag Type").font(.caption).foregroundColor(.secondary)
                    Divider()
                    ForEach(["Function", "Class", "Fix", "Feature", "API", "Model", "View", "Service"], id: \.self) { tag in
                        Button(action: { 
                            // Filter by tag type
                        }) {
                            Label("#\(tag)", systemImage: "tag")
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 10))
                        Text("Finder")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(4)
                }
                .menuStyle(.borderlessButton)
                .help("Smart Finder - Filter by tag type")
                
                Divider()
                    .frame(height: 14)
                    .padding(.horizontal, 4)
                
                // Index
                HeaderIconButton(
                    icon: "database",
                    label: appState.microCodeService?.isIndexing ?? false ? "Indexing..." : "Index",
                    isActive: appState.microCodeService?.isIndexing ?? false
                ) {
                    Task { await appState.microCodeService?.indexProject() }
                }
                
                Divider()
                    .frame(height: 14)
                    .padding(.horizontal, 4)
                
                HeaderIconButton(icon: "arrow.uturn.backward", label: nil) {
                    Task { await agent.undo() }
                }.help("Undo Last Action")
                
                HeaderIconButton(icon: "trash", label: nil) {
                    agent.clearCurrentChat()
                    attachments.removeAll()
                }.help("Clear This Chat")
            }
            .padding(.trailing, 8)
        }
        .frame(height: 36)
        .background(paneColor)
    }
    
    // MARK: - Input Area
    
    private var inputArea: some View {
        VStack(spacing: 0) {
            Divider().background(borderColor)
            
            // Attachment Pills
            if !attachments.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(attachments.indices, id: \.self) { index in
                            if index < attachments.count {
                                let file = attachments[index]
                                HStack(spacing: 4) {
                                    Image(systemName: fileIcon(for: file.type))
                                        .font(.system(size: 10))
                                    Text(file.name)
                                        .font(.system(size: 10))
                                        .lineLimit(1)
                                    
                                    Button(action: { attachments.remove(at: index) }) {
                                        Image(systemName: "xmark")
                                            .font(.system(size: 8))
                                            .foregroundColor(.secondary)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(4)
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
                }
            }
            
            HStack(alignment: .bottom, spacing: 12) {
                // Attach Button
                Button(action: pickFile) {
                    Image(systemName: "paperclip")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .padding(.bottom, 2)
                
                // Context Indicator
                if let file = appState.currentFile {
                    Button(action: {}) {
                        HStack(spacing: 4) {
                            Image(systemName: "doc.text")
                            Text(file.name)
                        }
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .padding(4)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, 6)
                }
                
                // Text Field
                if #available(macOS 13.0, *) {
                    TextField("Instructions...", text: $inputText, axis: .vertical)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13, design: .monospaced))
                        .lineLimit(1...5)
                        .focused($isInputFocused)
                        .padding(8)
                        .background(Color(nsColor: .textBackgroundColor))
                        .cornerRadius(4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(isInputFocused ? accentColor : borderColor, lineWidth: 1)
                        )
                        .onSubmit {
                            if !inputText.isEmpty { sendMessage() }
                        }
                } else {
                    TextField("Instructions...", text: $inputText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13, design: .monospaced))
                        .focused($isInputFocused)
                        .padding(8)
                        .background(Color(nsColor: .textBackgroundColor))
                        .cornerRadius(4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(isInputFocused ? accentColor : borderColor, lineWidth: 1)
                        )
                        .onSubmit {
                            if !inputText.isEmpty { sendMessage() }
                        }
                }
                
                // Send Button
                Button(action: sendMessage) {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.white)
                        .frame(width: 28, height: 28)
                        .background(accentColor)
                        .cornerRadius(4)
                }
                .buttonStyle(.plain)
                .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && attachments.isEmpty)
                .padding(.bottom, 1)
            }
            .padding(12)
            .background(paneColor)
        }
    }
    
    // MARK: - File Attachment Logic
    
    private func pickFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        
        if panel.runModal() == .OK {
            for url in panel.urls {
                processFile(url)
            }
        }
    }
    
    private func processFile(_ url: URL) {
        do {
            let data = try Data(contentsOf: url)
            let ext = url.pathExtension.lowercased()
            let fileName = url.lastPathComponent
            
            var type: AIAttachment.AttachmentType = .text
            
            if ["png", "jpg", "jpeg", "webp", "heic"].contains(ext) {
                type = .image(format: ext == "jpg" ? "jpeg" : ext)
            } else if ext == "pdf" {
                type = .pdf
            } else {
                type = .text // Default to text for code files
            }
            
            let attachment = AIAttachment(name: fileName, data: data, type: type)
            attachments.append(attachment)
        } catch {
            print("Failed to read file: \(error)")
        }
    }
    
    private func fileIcon(for type: AIAttachment.AttachmentType) -> String {
        switch type {
        case .image: return "photo"
        case .pdf: return "doc.text.fill" // Generic doc
        case .text: return "doc.text"
        }
    }
    
    private func sendMessage() {
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !attachments.isEmpty else { return }
        let userText = inputText
        let currentAttachments = attachments
        
        inputText = ""
        attachments = [] // Clear immediately
        
        let userMessage = AgentMessageModel(
            id: UUID().uuidString,
            role: .user,
            content: userText + (currentAttachments.isEmpty ? "" : "\n[Attached: \(currentAttachments.map(\.name).joined(separator: ", "))]"),
            toolResults: [],
            pendingChanges: [],
            timestamp: Date()
        )
        agent.messages.append(userMessage)
        
        let responseId = UUID().uuidString
        let streamingMessage = AgentMessageModel(
            id: responseId,
            role: .assistant,
            content: "",
            toolResults: [],
            pendingChanges: [],
            timestamp: Date()
        )
        agent.messages.append(streamingMessage)
        agent.isLoading = true
        
        let providerString = appState.aiProvider
        let provider: StreamableAIProvider = StreamableAIProvider(rawValue: providerString) ?? .gemini
        let model = appState.aiModel.isEmpty ? provider.defaultModel : appState.aiModel
        let apiKey = appState.apiKeys[providerString] ?? ""
        
        let systemPrompt = "You are MicroCode, a senior software engineer. Provide professional, concise, and correct solutions. Use code blocks for all code snippets."
        
        AIClient.shared.sendMessage(
            prompt: userText,
            attachments: currentAttachments,
            systemPrompt: systemPrompt,
            provider: provider,
            model: model,
            apiKey: apiKey,
            onToken: { token in
                if let idx = self.agent.messages.firstIndex(where: { $0.id == responseId }) {
                    let current = self.agent.messages[idx].content
                    self.agent.messages[idx] = AgentMessageModel(
                        id: responseId,
                        role: .assistant,
                        content: current + token,
                        toolResults: [],
                        pendingChanges: [],
                        timestamp: Date()
                    )
                }
            },
            onComplete: { _ in self.agent.isLoading = false },
            onError: { error in
                if let idx = self.agent.messages.firstIndex(where: { $0.id == responseId }) {
                    self.agent.messages[idx] = AgentMessageModel(
                        id: responseId,
                        role: .assistant,
                        content: "Error: \(error)",
                        toolResults: [],
                        pendingChanges: [],
                        timestamp: Date()
                    )
                }
                self.agent.isLoading = false
            }
        )
    }
}

// MARK: - Header Button (Reusable)

struct HeaderIconButton: View {
    let icon: String
    let label: String?
    var isActive: Bool = false
    let action: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if isActive {
                    ProgressView()
                        .scaleEffect(0.5)
                        .frame(width: 12, height: 12)
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 12))
                }
                
                if let text = label {
                    Text(text)
                        .font(.system(size: 11))
                }
            }
            .foregroundColor(isHovering || isActive ? .primary : .secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(isHovering ? Color.white.opacity(0.1) : Color.clear)
            .cornerRadius(4)
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }
}

// MARK: - Rich Message Renderer

enum MessageBlock: Identifiable {
    case text(String)
    case code(String, String) // Language, Content
    case heading(Int, String) // Level (1-6), Content
    case list([String], Bool) // Items, isOrdered
    case blockquote(String)
    case latex(String, Bool) // Expression, isBlock ($$...$$ vs $...$)
    case html(String)
    
    var id: String {
        switch self {
        case .text(let c): return "text-\(c.hashValue)"
        case .code(let l, let c): return "code-\(l)-\(c.hashValue)"
        case .heading(let lv, let c): return "h\(lv)-\(c.hashValue)"
        case .list(let items, _): return "list-\(items.hashValue)"
        case .blockquote(let c): return "quote-\(c.hashValue)"
        case .latex(let e, _): return "latex-\(e.hashValue)"
        case .html(let c): return "html-\(c.hashValue)"
        }
    }
}

struct MessageContentParser {
    static func parse(_ content: String) -> [MessageBlock] {
        var blocks: [MessageBlock] = []
        var remaining = content
        
        // First, extract code blocks
        let codePattern = "```([a-zA-Z0-9]*)\n([\\s\\S]*?)```"
        if let regex = try? NSRegularExpression(pattern: codePattern, options: []) {
            var offset = 0
            let nsContent = remaining as NSString
            let matches = regex.matches(in: remaining, options: [], range: NSRange(location: 0, length: nsContent.length))
            
            var lastEnd = 0
            for match in matches {
                // Text before code block
                if match.range.location > lastEnd {
                    let beforeRange = NSRange(location: lastEnd, length: match.range.location - lastEnd)
                    let beforeText = nsContent.substring(with: beforeRange)
                    blocks.append(contentsOf: parseTextContent(beforeText))
                }
                
                // Code block
                let langRange = match.range(at: 1)
                let codeRange = match.range(at: 2)
                let lang = langRange.location != NSNotFound ? nsContent.substring(with: langRange) : ""
                let code = codeRange.location != NSNotFound ? nsContent.substring(with: codeRange) : ""
                blocks.append(.code(lang, code.trimmingCharacters(in: .whitespacesAndNewlines)))
                
                lastEnd = match.range.location + match.range.length
            }
            
            // Remaining text after last code block
            if lastEnd < nsContent.length {
                let afterText = nsContent.substring(from: lastEnd)
                blocks.append(contentsOf: parseTextContent(afterText))
            }
        } else {
            // Fallback: simple split
            blocks.append(contentsOf: parseTextContent(content))
        }
        
        return blocks
    }
    
    private static func parseTextContent(_ text: String) -> [MessageBlock] {
        var blocks: [MessageBlock] = []
        let lines = text.components(separatedBy: "\n")
        var currentText: [String] = []
        var listItems: [String] = []
        var isOrderedList = false
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // Check for headings (# H1, ## H2, etc.)
            if let match = trimmed.range(of: "^#{1,6}\\s+", options: .regularExpression) {
                // Flush current text
                if !currentText.isEmpty {
                    blocks.append(.text(currentText.joined(separator: "\n")))
                    currentText = []
                }
                // Flush list
                if !listItems.isEmpty {
                    blocks.append(.list(listItems, isOrderedList))
                    listItems = []
                }
                
                let level = trimmed.prefix(while: { $0 == "#" }).count
                let heading = String(trimmed[match.upperBound...])
                blocks.append(.heading(level, heading))
                continue
            }
            
            // Check for block LaTeX ($$...$$)
            if trimmed.hasPrefix("$$") && trimmed.hasSuffix("$$") && trimmed.count > 4 {
                if !currentText.isEmpty {
                    blocks.append(.text(currentText.joined(separator: "\n")))
                    currentText = []
                }
                let latex = String(trimmed.dropFirst(2).dropLast(2))
                blocks.append(.latex(latex, true))
                continue
            }
            
            // Check for blockquote (> ...)
            if trimmed.hasPrefix("> ") {
                if !currentText.isEmpty {
                    blocks.append(.text(currentText.joined(separator: "\n")))
                    currentText = []
                }
                if !listItems.isEmpty {
                    blocks.append(.list(listItems, isOrderedList))
                    listItems = []
                }
                blocks.append(.blockquote(String(trimmed.dropFirst(2))))
                continue
            }
            
            // Check for unordered list (- or * item)
            if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
                if !currentText.isEmpty {
                    blocks.append(.text(currentText.joined(separator: "\n")))
                    currentText = []
                }
                isOrderedList = false
                listItems.append(String(trimmed.dropFirst(2)))
                continue
            }
            
            // Check for ordered list (1. item)
            if let _ = trimmed.range(of: "^\\d+\\.\\s+", options: .regularExpression) {
                if !currentText.isEmpty {
                    blocks.append(.text(currentText.joined(separator: "\n")))
                    currentText = []
                }
                isOrderedList = true
                listItems.append(String(trimmed.drop(while: { $0.isNumber || $0 == "." || $0 == " " })))
                continue
            }
            
            // Flush list if we hit non-list line
            if !listItems.isEmpty && !trimmed.isEmpty {
                blocks.append(.list(listItems, isOrderedList))
                listItems = []
            }
            
            // Regular text
            currentText.append(line)
        }
        
        // Flush remaining
        if !listItems.isEmpty {
            blocks.append(.list(listItems, isOrderedList))
        }
        if !currentText.isEmpty {
            let joined = currentText.joined(separator: "\n")
            if !joined.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                blocks.append(.text(joined))
            }
        }
        
        return blocks
    }
}

// MARK: - Chat Stage

struct AgentChatStage: View {
    let messages: [AgentMessageModel]
    let isLoading: Bool
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    if messages.isEmpty && !isLoading {
                        VStack(spacing: 16) {
                            Spacer().frame(height: 60)
                            Image(systemName: "terminal")
                                .font(.system(size: 48))
                                .foregroundColor(.white.opacity(0.05))
                            Text("Ready to code.")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary.opacity(0.5))
                        }
                    } else {
                        ForEach(messages) { message in
                            RichMessageRow(message: message)
                                .id(message.id)
                        }
                    }
                    
                    if isLoading {
                        HStack(spacing: 8) {
                            ProgressView()
                                .scaleEffect(0.5)
                                .frame(width: 16, height: 16)
                            Text("Generating...")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        .padding(16)
                    }
                }
                .padding(.bottom, 120) // Extra space for input area
            }
            .onChange(of: messages.count) { _ in
                if let lastId = messages.last?.id {
                    proxy.scrollTo(lastId, anchor: .bottom)
                }
            }
        }
    }
}

// MARK: - Rich Message Row

struct RichMessageRow: View {
    let message: AgentMessageModel
    
    var isUser: Bool { message.role == .user }
    
    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            // Icon
            VStack {
                if isUser {
                    Circle()
                        .fill(Color.secondary.opacity(0.2))
                        .frame(width: 20, height: 20)
                        .overlay(Image(systemName: "person.fill").font(.system(size: 10)).foregroundColor(.secondary))
                } else {
                    Rectangle()
                        .fill(Color.accentColor)
                        .frame(width: 20, height: 20)
                        .cornerRadius(4)
                        .overlay(Image(systemName: "command").font(.system(size: 10)).foregroundColor(.white))
                }
            }
            .padding(.top, 10)
            .padding(.leading, 16)
            .padding(.trailing, 12)
            
            // Content
            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack {
                    Text(isUser ? "USER" : "MICROCODE")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(isUser ? .secondary : .accentColor)
                    
                    Text(message.timestamp.formatted(date: .omitted, time: .shortened))
                        .font(.system(size: 10))
                        .foregroundColor(.secondary.opacity(0.5))
                }
                .padding(.top, 12)
                
                // Blocks
                let blocks = MessageContentParser.parse(message.content)
                ForEach(blocks) { block in
                    switch block {
                    case .text(let text):
                        if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            MarkdownTextView(text: text)
                        }
                        
                    case .code(let lang, let code):
                        NativeCodeBlockView(language: lang, code: code)
                        
                    case .heading(let level, let content):
                        HeadingView(level: level, content: content)
                        
                    case .list(let items, let isOrdered):
                        ListView(items: items, isOrdered: isOrdered)
                        
                    case .blockquote(let content):
                        BlockquoteView(content: content)
                        
                    case .latex(let expression, let isBlock):
                        LaTeXBlockView(expression: expression, isBlock: isBlock)
                        
                    case .html(let content):
                        HTMLBlockView(content: content)
                    }
                }
                
                // Tool Outputs (if any)
                if !message.toolResults.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(message.toolResults, id: \.toolCallId) { result in
                            HStack(spacing: 6) {
                                Image(systemName: result.success ? "checkmark" : "xmark")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(result.success ? .green : .red)
                                Text(result.output)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                            .padding(6)
                            .background(Color.black.opacity(0.2))
                            .cornerRadius(4)
                        }
                    }
                }
                
                Divider()
                    .background(Color.white.opacity(0.05))
                    .padding(.top, 4)
            }
            .padding(.trailing, 16)
        }
        .background(isUser ? Color.clear : Color.white.opacity(0.02))
    }
}

// MARK: - Rich Text Components

/// Renders inline markdown (bold, italic, links)
struct MarkdownTextView: View {
    let text: String
    
    var body: some View {
        Text(attributedText)
            .font(.system(size: 13))
            .frame(maxWidth: .infinity, alignment: .leading)
            .foregroundColor(.primary)
            .lineSpacing(5)
            .textSelection(.enabled)
    }
    
    private var attributedText: AttributedString {
        var str = AttributedString(text)
        
        // Apply bold (**text** or __text__)
        if let boldRegex = try? Regex("\\*\\*(.+?)\\*\\*|__(.+?)__") {
            for match in text.matches(of: boldRegex) {
                if let range = str.range(of: String(match.0)) {
                    str[range].font = .system(size: 13, weight: .bold)
                }
            }
        }
        
        // Apply italic (*text* or _text_) - but not bold
        if let italicRegex = try? Regex("(?<![*_])\\*([^*]+)\\*(?![*_])|(?<![*_])_([^_]+)_(?![*_])") {
            for match in text.matches(of: italicRegex) {
                if let range = str.range(of: String(match.0)) {
                    str[range].font = .system(size: 13).italic()
                }
            }
        }
        
        // Apply inline code (`code`)
        if let codeRegex = try? Regex("`([^`]+)`") {
            for match in text.matches(of: codeRegex) {
                if let range = str.range(of: String(match.0)) {
                    str[range].font = .system(size: 12, design: .monospaced)
                    str[range].backgroundColor = Color(nsColor: .controlBackgroundColor)
                }
            }
        }
        
        return str
    }
}

/// Renders heading with proper font size
struct HeadingView: View {
    let level: Int
    let content: String
    
    var body: some View {
        Text(content)
            .font(.system(size: fontSize, weight: .bold))
            .foregroundColor(.primary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, topPadding)
            .padding(.bottom, 4)
    }
    
    private var fontSize: CGFloat {
        switch level {
        case 1: return 24
        case 2: return 20
        case 3: return 17
        case 4: return 15
        case 5: return 14
        default: return 13
        }
    }
    
    private var topPadding: CGFloat {
        level <= 2 ? 8 : 4
    }
}

/// Renders ordered/unordered list
struct ListView: View {
    let items: [String]
    let isOrdered: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(items.indices, id: \.self) { index in
                HStack(alignment: .top, spacing: 8) {
                    Text(isOrdered ? "\(index + 1)." : "•")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .frame(width: 20, alignment: isOrdered ? .trailing : .center)
                    
                    Text(items[index])
                        .font(.system(size: 13))
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(.leading, 8)
    }
}

/// Renders blockquote
struct BlockquoteView: View {
    let content: String
    
    var body: some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(Color.accentColor.opacity(0.6))
                .frame(width: 3)
            
            Text(content)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .italic()
                .padding(.leading, 12)
                .padding(.vertical, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Renders LaTeX equation via MathJax WebView
struct LaTeXBlockView: View {
    let expression: String
    let isBlock: Bool
    
    var body: some View {
        VStack(alignment: isBlock ? .center : .leading, spacing: 0) {
            LaTeXWebView(expression: expression, isBlock: isBlock)
                .frame(height: isBlock ? 80 : 40)
                .frame(maxWidth: .infinity)
        }
        .background(Color(nsColor: .textBackgroundColor).opacity(0.3))
        .cornerRadius(6)
    }
}

/// Renders HTML content
struct HTMLBlockView: View {
    let content: String
    
    var body: some View {
        HTMLWebView(content: content)
            .frame(minHeight: 100)
            .frame(maxWidth: .infinity)
            .cornerRadius(6)
    }
}

// MARK: - LaTeX WebView (MathJax)

import WebKit

struct LaTeXWebView: NSViewRepresentable {
    let expression: String
    let isBlock: Bool
    
    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.setValue(true, forKey: "drawsBackground")
        webView.isHidden = false
        return webView
    }
    
    func updateNSView(_ webView: WKWebView, context: Context) {
        let delim = isBlock ? "\\[\\]" : "\\(\\)"
        let left = isBlock ? "\\[" : "\\("
        let right = isBlock ? "\\]" : "\\)"
        
        let html = """
        <!DOCTYPE html>
        <html>
        <head>
            <script src="https://polyfill.io/v3/polyfill.min.js?features=es6"></script>
            <script id="MathJax-script" async src="https://cdn.jsdelivr.net/npm/mathjax@3/es5/tex-mml-chtml.js"></script>
            <style>
                body {
                    margin: 0;
                    padding: 8px;
                    background: transparent;
                    display: flex;
                    align-items: center;
                    justify-content: \(isBlock ? "center" : "flex-start");
                    font-size: 14px;
                    color: #e0e0e0;
                }
            </style>
        </head>
        <body>
            \(left)\(expression)\(right)
        </body>
        </html>
        """
        webView.loadHTMLString(html, baseURL: nil)
    }
}

// MARK: - HTML WebView

struct HTMLWebView: NSViewRepresentable {
    let content: String
    
    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView()
        return webView
    }
    
    func updateNSView(_ webView: WKWebView, context: Context) {
        let html = """
        <!DOCTYPE html>
        <html>
        <head>
            <style>
                body {
                    font-family: -apple-system, BlinkMacSystemFont, sans-serif;
                    font-size: 13px;
                    color: #e0e0e0;
                    background: #1e1e1e;
                    padding: 12px;
                    margin: 0;
                }
                table { border-collapse: collapse; width: 100%; }
                th, td { border: 1px solid #444; padding: 8px; text-align: left; }
                th { background: #2d2d2d; }
                a { color: #58a6ff; }
            </style>
        </head>
        <body>
            \(content)
        </body>
        </html>
        """
        webView.loadHTMLString(html, baseURL: nil)
    }
}

// MARK: - Dynamic Code Tag Generator

/// Generates meaningful tags from code content in real-time
struct CodeTagGenerator {
    
    /// Generate a smart tag from code analysis
    static func generateTag(from code: String, language: String) -> String {
        // 1. Try to extract function/method name
        if let funcName = extractFunctionName(from: code, language: language) {
            return "#\(funcName)"
        }
        
        // 2. Try to extract class/struct name
        if let className = extractClassName(from: code, language: language) {
            return "#\(className)"
        }
        
        // 3. Try to detect purpose from comments
        if let purpose = detectPurpose(from: code) {
            return "#\(purpose)"
        }
        
        // 4. Fallback to language + line count
        let lineCount = code.components(separatedBy: "\n").count
        let lang = language.isEmpty ? "Code" : language.capitalized
        return "#\(lang)\(lineCount)L"
    }
    
    /// Extract function/method name
    private static func extractFunctionName(from code: String, language: String) -> String? {
        let patterns: [String]
        
        switch language.lowercased() {
        case "swift":
            patterns = [
                #"func\s+([a-zA-Z_][a-zA-Z0-9_]*)"#,
                #"private\s+func\s+([a-zA-Z_][a-zA-Z0-9_]*)"#
            ]
        case "python":
            patterns = [#"def\s+([a-zA-Z_][a-zA-Z0-9_]*)"#]
        case "javascript", "typescript", "js", "ts":
            patterns = [
                #"function\s+([a-zA-Z_][a-zA-Z0-9_]*)"#,
                #"const\s+([a-zA-Z_][a-zA-Z0-9_]*)\s*=\s*\("#,
                #"([a-zA-Z_][a-zA-Z0-9_]*)\s*=\s*async"#
            ]
        case "rust":
            patterns = [#"fn\s+([a-zA-Z_][a-zA-Z0-9_]*)"#]
        case "go", "golang":
            patterns = [#"func\s+([a-zA-Z_][a-zA-Z0-9_]*)"#]
        case "java", "kotlin":
            patterns = [
                #"public\s+\w+\s+([a-zA-Z_][a-zA-Z0-9_]*)\s*\("#,
                #"private\s+\w+\s+([a-zA-Z_][a-zA-Z0-9_]*)\s*\("#,
                #"fun\s+([a-zA-Z_][a-zA-Z0-9_]*)"#
            ]
        default:
            patterns = [#"func\s+([a-zA-Z_][a-zA-Z0-9_]*)"#, #"function\s+([a-zA-Z_][a-zA-Z0-9_]*)"#]
        }
        
        for pattern in patterns {
            if let match = code.firstMatch(pattern: pattern) {
                return match
            }
        }
        return nil
    }
    
    /// Extract class/struct/type name
    private static func extractClassName(from code: String, language: String) -> String? {
        let patterns: [String]
        
        switch language.lowercased() {
        case "swift":
            patterns = [
                #"class\s+([a-zA-Z_][a-zA-Z0-9_]*)"#,
                #"struct\s+([a-zA-Z_][a-zA-Z0-9_]*)"#,
                #"enum\s+([a-zA-Z_][a-zA-Z0-9_]*)"#
            ]
        case "python":
            patterns = [#"class\s+([a-zA-Z_][a-zA-Z0-9_]*)"#]
        case "javascript", "typescript", "js", "ts":
            patterns = [
                #"class\s+([a-zA-Z_][a-zA-Z0-9_]*)"#,
                #"interface\s+([a-zA-Z_][a-zA-Z0-9_]*)"#,
                #"type\s+([a-zA-Z_][a-zA-Z0-9_]*)"#
            ]
        case "rust":
            patterns = [
                #"struct\s+([a-zA-Z_][a-zA-Z0-9_]*)"#,
                #"enum\s+([a-zA-Z_][a-zA-Z0-9_]*)"#,
                #"impl\s+([a-zA-Z_][a-zA-Z0-9_]*)"#
            ]
        case "java", "kotlin":
            patterns = [
                #"class\s+([a-zA-Z_][a-zA-Z0-9_]*)"#,
                #"interface\s+([a-zA-Z_][a-zA-Z0-9_]*)"#,
                #"data\s+class\s+([a-zA-Z_][a-zA-Z0-9_]*)"#
            ]
        default:
            patterns = [#"class\s+([a-zA-Z_][a-zA-Z0-9_]*)"#]
        }
        
        for pattern in patterns {
            if let match = code.firstMatch(pattern: pattern) {
                return match
            }
        }
        return nil
    }
    
    /// Detect purpose from comments
    private static func detectPurpose(from code: String) -> String? {
        let lower = code.lowercased()
        
        if lower.contains("fix:") || lower.contains("// fix") || lower.contains("bugfix") {
            return "Fix"
        }
        if lower.contains("todo:") || lower.contains("// todo") {
            return "TODO"
        }
        if lower.contains("feature:") || lower.contains("new feature") {
            return "Feature"
        }
        if lower.contains("refactor") {
            return "Refactor"
        }
        if lower.contains("test") || lower.contains("spec") {
            return "Test"
        }
        if lower.contains("example") || lower.contains("demo") || lower.contains("sample") {
            return "Example"
        }
        if lower.contains("api") || lower.contains("endpoint") {
            return "API"
        }
        if lower.contains("model") || lower.contains("entity") {
            return "Model"
        }
        if lower.contains("view") || lower.contains("component") || lower.contains("ui") {
            return "View"
        }
        if lower.contains("service") || lower.contains("manager") {
            return "Service"
        }
        
        return nil
    }
}

// String extension for regex matching
extension String {
    func firstMatch(pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return nil
        }
        let range = NSRange(self.startIndex..., in: self)
        if let match = regex.firstMatch(in: self, options: [], range: range),
           match.numberOfRanges > 1,
           let captureRange = Range(match.range(at: 1), in: self) {
            return String(self[captureRange])
        }
        return nil
    }
}

/// Dynamic tag with auto-generated name
struct DynamicTag: Equatable {
    let name: String
    let color: Color
    
    static let none = DynamicTag(name: "", color: .gray)
    
    var isEmpty: Bool { name.isEmpty }
    
    init(name: String, color: Color = .accentColor) {
        self.name = name
        self.color = DynamicTag.colorFor(name: name)
    }
    
    private static func colorFor(name: String) -> Color {
        let lower = name.lowercased()
        if lower.contains("fix") || lower.contains("bug") { return .orange }
        if lower.contains("feature") || lower.contains("new") { return .green }
        if lower.contains("refactor") { return .purple }
        if lower.contains("test") { return .yellow }
        if lower.contains("api") || lower.contains("service") { return .cyan }
        if lower.contains("view") || lower.contains("ui") { return .pink }
        if lower.contains("model") { return .teal }
        // Hash-based color for unique names
        let hash = abs(name.hashValue)
        let colors: [Color] = [.blue, .indigo, .mint, .orange, .pink, .purple, .teal, .cyan]
        return colors[hash % colors.count]
    }
}

struct NativeCodeBlockView: View {
    let language: String
    let code: String
    
    @State private var isCopied = false
    @State private var isHovering = false
    
    // Auto-color based on language
    private var autoColorTheme: CellColorTheme {
        switch language.lowercased() {
        case "swift": return .orange
        case "python": return .blue
        case "javascript", "js", "typescript", "ts": return .yellow
        case "html": return .red
        case "css", "scss", "sass": return .purple
        case "rust": return .brown
        case "go", "golang": return .cyan
        case "java", "kotlin": return .teal
        case "ruby": return .red
        case "php": return .indigo
        case "c", "cpp", "c++", "objc", "objective-c": return .gray
        case "shell", "bash", "zsh": return .green
        case "sql": return .mint
        case "json", "yaml", "xml": return .pink
        default: return .blue
        }
    }
    
    private var blockBackground: Color {
        autoColorTheme.color
    }
    
    private var blockBorder: Color {
        autoColorTheme.borderColor.opacity(0.4)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 0) {
                // Left Gutter
                gutterView
                
                // Main Cell Content
                VStack(spacing: 0) {
                    headerView
                    codeContentView
                }
            }
        }
        .background(blockBackground)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(blockBorder, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
        .padding(.vertical, 8)
        .onHover { isHovering = $0 }
    }
    
    // MARK: - Subviews
    
    // MARK: - Computed Properties
    
    private var lineCount: Int {
        code.components(separatedBy: "\n").count
    }
    
    private var isLongCode: Bool {
        lineCount > 15
    }
    
    private var gutterView: some View {
        VStack(alignment: .trailing, spacing: 0) {
            ForEach(1...min(lineCount, isExpanded ? lineCount : 15), id: \.self) { lineNum in
                Text("\(lineNum)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary.opacity(0.6))
                    .frame(height: 18)
            }
            
            if isLongCode && !isExpanded {
                Text("...")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary.opacity(0.4))
                    .frame(height: 18)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .frame(width: 36)
        .background(autoColorTheme.color.opacity(0.3))
    }
    
    private var headerView: some View {
        HStack(spacing: 8) {
            // Language Badge
            HStack(spacing: 6) {
                Circle()
                    .fill(autoColorTheme.iconColor)
                    .frame(width: 8, height: 8)
                
                Text(language.isEmpty ? "Plain Text" : language.capitalized)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.primary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.black.opacity(0.2))
            .cornerRadius(4)
            
            // Auto-Generated Tag
            if !dynamicTag.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "tag.fill")
                        .font(.system(size: 8))
                    Text(dynamicTag.name)
                        .font(.system(size: 9, weight: .medium))
                }
                .foregroundColor(dynamicTag.color)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(dynamicTag.color.opacity(0.15))
                .cornerRadius(3)
            }
            
            // Line Count Badge
            Text("\(lineCount) lines")
                .font(.system(size: 9))
                .foregroundColor(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.white.opacity(0.05))
                .cornerRadius(3)
            
            Spacer()
            
            // Tools (Always visible but subtle, brighter on hover)
            HStack(spacing: 4) {
                // Run Menu (NEW!)
                Menu {
                    Button(action: runInPlayground) {
                        Label("Run in Playground", systemImage: "play.rectangle")
                    }
                    Button(action: runInCellMode) {
                        Label("Run in Cell Mode", systemImage: "square.grid.2x2")
                    }
                    Divider()
                    Button(action: openInEditor) {
                        Label("Open in Editor", systemImage: "doc.text")
                    }
                } label: {
                    Image(systemName: "play.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.green.opacity(isHovering ? 1 : 0.6))
                }
                .menuStyle(.borderlessButton)
                .frame(width: 20)
                .help("Run Code")
                
                // Expand/Collapse (for long code)
                if isLongCode {
                    Button(action: { 
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isExpanded.toggle() 
                        }
                    }) {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary.opacity(isHovering ? 1 : 0.5))
                    }
                    .buttonStyle(.plain)
                    .frame(width: 20)
                }
                
                // Copy Button
                Button(action: copyCode) {
                    HStack(spacing: 3) {
                        Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 10))
                        if isHovering {
                            Text(isCopied ? "Copied" : "Copy")
                                .font(.system(size: 9))
                        }
                    }
                    .foregroundColor(isCopied ? .green : .secondary.opacity(isHovering ? 1 : 0.6))
                    .padding(.horizontal, isHovering ? 6 : 4)
                    .padding(.vertical, 3)
                    .background(Color.white.opacity(isHovering ? 0.08 : 0.03))
                    .cornerRadius(4)
                }
                .buttonStyle(.plain)
            }
            .animation(.easeInOut(duration: 0.15), value: isHovering)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.6))
    }
    
    // MARK: - Dynamic Tag
    
    private var dynamicTag: DynamicTag {
        DynamicTag(name: CodeTagGenerator.generateTag(from: code, language: language))
    }
    
    // MARK: - Run Actions
    
    private func runInPlayground() {
        // Copy code to clipboard and switch to playground mode
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(code, forType: .string)
        
        // Get appState from environment and switch mode
        NotificationCenter.default.post(
            name: Notification.Name("OpenInPlayground"), 
            object: nil, 
            userInfo: ["code": code, "language": language]
        )
    }
    
    private func runInCellMode() {
        // Copy code and switch to cell mode
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(code, forType: .string)
        
        NotificationCenter.default.post(
            name: Notification.Name("OpenInCellMode"), 
            object: nil, 
            userInfo: ["code": code, "language": language]
        )
    }
    
    private func openInEditor() {
        // Create a new temp file and open it
        let ext = languageExtension(for: language)
        let fileName = "ai_code_\(Int(Date().timeIntervalSince1970)).\(ext)"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        do {
            try code.write(to: tempURL, atomically: true, encoding: .utf8)
            NotificationCenter.default.post(
                name: Notification.Name("OpenFileInEditor"), 
                object: nil, 
                userInfo: ["url": tempURL]
            )
        } catch {
            print("Failed to create temp file: \(error)")
        }
    }
    
    private func languageExtension(for lang: String) -> String {
        switch lang.lowercased() {
        case "swift": return "swift"
        case "python": return "py"
        case "javascript", "js": return "js"
        case "typescript", "ts": return "ts"
        case "rust": return "rs"
        case "go", "golang": return "go"
        case "java": return "java"
        case "kotlin": return "kt"
        case "ruby": return "rb"
        case "c": return "c"
        case "cpp", "c++": return "cpp"
        case "html": return "html"
        case "css": return "css"
        case "sql": return "sql"
        case "shell", "bash": return "sh"
        default: return "txt"
        }
    }
    
    @State private var isExpanded = false
    
    private var codeContentView: some View {
        let lines = code.components(separatedBy: "\n")
        let displayLines = isExpanded || !isLongCode ? lines : Array(lines.prefix(15))
        
        return VStack(alignment: .leading, spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(displayLines.indices, id: \.self) { idx in
                        Text(displayLines[idx].isEmpty ? " " : displayLines[idx])
                            .font(.custom("Menlo", size: 12))
                            .foregroundColor(Color(nsColor: .textColor))
                            .frame(height: 18, alignment: .leading)
                            .textSelection(.enabled)
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
            }
            
            // Expand indicator
            if isLongCode && !isExpanded {
                HStack {
                    Spacer()
                    Button(action: { 
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isExpanded = true 
                        }
                    }) {
                        HStack(spacing: 4) {
                            Text("Show \(lineCount - 15) more lines")
                                .font(.system(size: 10))
                            Image(systemName: "chevron.down")
                                .font(.system(size: 9))
                        }
                        .foregroundColor(.accentColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
                .background(
                    LinearGradient(
                        colors: [autoColorTheme.color.opacity(0), autoColorTheme.color.opacity(0.3)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
        }
        .background(Color(nsColor: .textBackgroundColor).opacity(0.15))
    }
    
    private func copyCode() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(code, forType: .string)
        withAnimation(.easeInOut(duration: 0.2)) {
            isCopied = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation(.easeInOut(duration: 0.2)) {
                isCopied = false
            }
        }
    }
}

// MARK: - Chat List Row

struct ChatListRow: View {
    let chat: ChatSession
    let isActive: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 8) {
                Image(systemName: "bubble.left.fill")
                    .font(.system(size: 10))
                    .foregroundColor(isActive ? .accentColor : .secondary)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(chat.name)
                        .font(.system(size: 11, weight: isActive ? .semibold : .regular))
                        .foregroundColor(isActive ? .primary : .secondary)
                        .lineLimit(1)
                    
                    Text(chat.messages.isEmpty ? "Empty" : "\(chat.messages.count) messages")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary.opacity(0.7))
                }
                
                Spacer()
                
                if isHovering {
                    Button(action: onDelete) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isActive ? Color.accentColor.opacity(0.15) : (isHovering ? Color.white.opacity(0.05) : Color.clear))
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
        }
        .contextMenu {
            Button("Delete Chat", role: .destructive) {
                onDelete()
            }
        }
    }
}
