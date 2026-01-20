//
//  AIAgentView.swift
//  CodeTunner
//
//  Redesigned by MicroCode AI
//  "Dotmini Glass" Aesthetic - MicroCode Agent Mode
//

import SwiftUI
import Combine
import CodeTunnerSupport

// MARK: - AI Agent View (Redesign)

struct AIAgentView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var agent = AgentService.shared
    
    @State private var inputText = ""
    @State private var isHoveringInput = false
    @State private var showSettings = false
    
    // Aesthetic Constants
    private let glassBackground = Color.white.opacity(0.9)
    private let messagePadding: CGFloat = 16
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // 1. Main Background
            Color.white // Pure white for light mode
                .edgesIgnoringSafeArea(.all)
            
            // 2. Chat Stage (Scroll Area)
            AgentChatStage(messages: agent.messages)
                .padding(.bottom, 80) // Leave space for floating input
            
            // 3. Floating Input Bar
            AgentFloatingInput(
                text: $inputText,
                isHovering: $isHoveringInput,
                onSend: sendMessage
            )
            .padding(.bottom, 32)
            
            // 4. Top Overlay (Actions)
            VStack {
                HStack {
                    Spacer()
                    
                    // RAG Index Button (Subtle pill)
                    Button(action: { Task { await appState.microCodeService?.indexProject() } }) {
                        HStack(spacing: 6) {
                            if appState.microCodeService?.isIndexing ?? false {
                                ProgressView()
                                    .scaleEffect(0.5)
                                    .frame(width: 12, height: 12)
                            } else {
                                Image(systemName: "database")
                                    .font(.system(size: 11))
                            }
                            Text(appState.microCodeService?.isIndexing ?? false ? "Indexing..." : "Index Knowledge")
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Material.ultraThin)
                        .cornerRadius(20)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.black.opacity(0.05), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(16)
                }
                Spacer()
            }
        }
    }
    
    private func sendMessage() {
        guard !inputText.isEmpty else { return }
        let text = inputText
        inputText = "" // Clear immediately
        
        Task {
            await agent.sendMessage(text)
        }
    }
}

// MARK: - Component: Chat Stage

struct AgentChatStage: View {
    let messages: [AgentMessageModel]
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 24) {
                    Spacer().frame(height: 20)
                    
                    if messages.isEmpty {
                        // Empty State / Welcome
                        VStack(spacing: 16) {
                            Image(systemName: "brain.head.profile")
                                .font(.system(size: 48, weight: .thin))
                                .foregroundColor(.black.opacity(0.1))
                            Text("MicroCode AI")
                                .font(.system(size: 18, weight: .semibold, design: .rounded))
                                .foregroundColor(.black.opacity(0.4))
                        }
                        .padding(.top, 100)
                        .opacity(0.8)
                    } else {
                        ForEach(messages) { message in
                            AgentMessageBubble(message: message)
                                .id(message.id)
                                .transition(.opacity.combined(with: .move(edge: .bottom)))
                        }
                    }
                    
                    Spacer().frame(height: 40)
                }
                .padding(.horizontal, 40) // Wide margin for focus
                .padding(.vertical, 20)
            }
            .onChange(of: messages.count) { _ in
                if let lastId = messages.last?.id {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        proxy.scrollTo(lastId, anchor: .bottom)
                    }
                }
            }
        }
    }
}

// MARK: - Component: Message Bubble

struct AgentMessageBubble: View {
    let message: AgentMessageModel
    @State private var isHovering = false
    
    var isUser: Bool { message.role == .user }
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            if isUser {
                Spacer()
                
                // User Message (Right Aligned, Minimal)
                Text(message.content)
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundColor(.black.opacity(0.8))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.black.opacity(0.03))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.black.opacity(0.05), lineWidth: 0.5)
                    )
                
            } else {
                // AI Message (Left Aligned, Distinct)
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles") // AI Icon
                            .foregroundStyle(LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .font(.system(size: 14))
                        
                        Text("MicroCode")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(.secondary.opacity(0.6))
                    }
                    .padding(.bottom, 2)
                    
                    // Content Analysis: Check for code blocks
                    if message.content.contains("```") {
                         // Simple Markdown rendering simulation
                         // In production, use a real MarkdownView
                         Text(message.content)
                            .font(.system(size: 14, weight: .regular, design: .rounded))
                            .lineSpacing(4)
                            .foregroundColor(.black.opacity(0.85))
                            .textSelection(.enabled)
                    } else {
                        Text(message.content)
                            .font(.system(size: 14, weight: .regular, design: .rounded))
                            .lineSpacing(4)
                            .foregroundColor(.black.opacity(0.85))
                            .textSelection(.enabled)
                    }
                    
                    // Tool Results (if any)
                    if !message.toolResults.isEmpty {
                        ForEach(message.toolResults, id: \.toolCallId) { result in
                            HStack {
                                Image(systemName: result.success ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                                    .foregroundColor(result.success ? .green.opacity(0.6) : .red.opacity(0.6))
                                Text(result.success ? "Action Completed" : "Action Failed")
                                    .font(.system(size: 11, weight: .medium, design: .rounded))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.top, 4)
                        }
                    }
                }
                .padding(.trailing, 40) // Don't stretch too wide
                
                Spacer()
            }
        }
        .onHover { isHovering = $0 }
    }
}

// MARK: - Component: Floating Input

struct AgentFloatingInput: View {
    @Binding var text: String
    @Binding var isHovering: Bool
    let onSend: () -> Void
    
    @FocusState private var isFocused: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // Attachment Button
            Button(action: {}) {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.secondary.opacity(0.8))
                    .frame(width: 32, height: 32)
                    .background(Color.black.opacity(isHovering ? 0.05 : 0))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            
            // Text Field
            TextField("Ask MicroCode...", text: $text)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .textFieldStyle(.plain)
                .focused($isFocused)
                .onSubmit(onSend)
            
            // Send Button
            Button(action: onSend) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(text.isEmpty ? .secondary.opacity(0.3) : .black)
                    .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
            }
            .buttonStyle(.plain)
            .disabled(text.isEmpty)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            ZStack {
                // Blur Effect
                VisualEffectView(material: .hudWindow, blendingMode: .withinWindow)
                    .opacity(0.9)
                Color.white.opacity(0.8)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.black.opacity(0.08), lineWidth: 1)
        )
        // Drop Shadow
        .shadow(
            color: Color.black.opacity(0.08),
            radius: 20,
            x: 0,
            y: 10
        )
        .frame(width: 600) // Fixed width for center stage feel
        .scaleEffect(isFocused ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isFocused)
        .onHover { isHovering = $0 }
    }
}
