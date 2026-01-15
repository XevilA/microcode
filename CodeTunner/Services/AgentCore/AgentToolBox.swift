//
//  AgentToolBox.swift
//  CodeTunner
//
//  Production-Grade AI Agent - ToolBox
//  Inspired by rust-agentai ToolBox macro
//

import Foundation

// MARK: - Agent Tool Protocol

protocol AgentTool {
    var name: String { get }
    var description: String { get }
    var parameters: [ToolParameter] { get }
    
    func execute(params: [String: Any]) async throws -> String
}

struct ToolParameter {
    let name: String
    let type: String
    let description: String
    let required: Bool
}

// MARK: - Agent ToolBox

@MainActor
class AgentToolBox: ObservableObject {
    static let shared = AgentToolBox()
    
    @Published var tools: [String: any AgentTool] = [:]
    @Published var executionHistory: [ToolExecution] = []
    
    init() {
        registerBuiltinTools()
    }
    
    private func registerBuiltinTools() {
        register(FileReadTool())
        register(FileWriteTool())
        register(FileSearchTool())
        register(CodeExecuteTool())
        register(CodeAnalyzeTool())
        register(GitStatusTool())
        register(WebFetchTool())
        register(ShellCommandTool())
    }
    
    func register(_ tool: any AgentTool) {
        tools[tool.name] = tool
    }
    
    func execute(_ toolName: String, params: [String: Any]) async throws -> String {
        guard let tool = tools[toolName] else {
            throw ToolBoxError.toolNotFound(toolName)
        }
        
        let startTime = Date()
        
        do {
            let result = try await tool.execute(params: params)
            
            let execution = ToolExecution(
                toolName: toolName,
                params: params,
                result: result,
                success: true,
                duration: Date().timeIntervalSince(startTime)
            )
            executionHistory.append(execution)
            
            return result
        } catch {
            let execution = ToolExecution(
                toolName: toolName,
                params: params,
                result: error.localizedDescription,
                success: false,
                duration: Date().timeIntervalSince(startTime)
            )
            executionHistory.append(execution)
            throw error
        }
    }
    
    var toolDescriptions: String {
        tools.values.map { tool in
            let params = tool.parameters.map { "\($0.name): \($0.type)" }.joined(separator: ", ")
            return "- \(tool.name)(\(params)): \(tool.description)"
        }.joined(separator: "\n")
    }
    
    var toolList: [any AgentTool] {
        Array(tools.values)
    }
}

struct ToolExecution: Identifiable {
    let id = UUID()
    let toolName: String
    let params: [String: Any]
    let result: String
    let success: Bool
    let duration: TimeInterval
    let timestamp = Date()
}

enum ToolBoxError: LocalizedError {
    case toolNotFound(String)
    case invalidParams(String)
    case executionFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .toolNotFound(let name): return "Tool not found: \(name)"
        case .invalidParams(let msg): return "Invalid parameters: \(msg)"
        case .executionFailed(let msg): return "Execution failed: \(msg)"
        }
    }
}

// MARK: - Built-in Tools

struct FileReadTool: AgentTool {
    let name = "file_read"
    let description = "Read contents of a file"
    let parameters = [
        ToolParameter(name: "path", type: "String", description: "File path", required: true)
    ]
    
    func execute(params: [String: Any]) async throws -> String {
        guard let path = params["path"] as? String ?? params["arg0"] as? String else {
            throw ToolBoxError.invalidParams("path is required")
        }
        
        let url = URL(fileURLWithPath: path)
        return try String(contentsOf: url, encoding: .utf8)
    }
}

struct FileWriteTool: AgentTool {
    let name = "file_write"
    let description = "Write content to a file"
    let parameters = [
        ToolParameter(name: "path", type: "String", description: "File path", required: true),
        ToolParameter(name: "content", type: "String", description: "Content to write", required: true)
    ]
    
    func execute(params: [String: Any]) async throws -> String {
        guard let path = params["path"] as? String ?? params["arg0"] as? String,
              let content = params["content"] as? String ?? params["arg1"] as? String else {
            throw ToolBoxError.invalidParams("path and content are required")
        }
        
        let url = URL(fileURLWithPath: path)
        try content.write(to: url, atomically: true, encoding: .utf8)
        return "File written successfully: \(path)"
    }
}

struct FileSearchTool: AgentTool {
    let name = "file_search"
    let description = "Search for files matching pattern"
    let parameters = [
        ToolParameter(name: "directory", type: "String", description: "Directory to search", required: true),
        ToolParameter(name: "pattern", type: "String", description: "Search pattern", required: true)
    ]
    
    func execute(params: [String: Any]) async throws -> String {
        guard let directory = params["directory"] as? String ?? params["arg0"] as? String,
              let pattern = params["pattern"] as? String ?? params["arg1"] as? String else {
            throw ToolBoxError.invalidParams("directory and pattern are required")
        }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/find")
        process.arguments = [directory, "-name", pattern, "-type", "f"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        try process.run()
        process.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }
}

struct CodeExecuteTool: AgentTool {
    let name = "code_execute"
    let description = "Execute code in specified language"
    let parameters = [
        ToolParameter(name: "language", type: "String", description: "Programming language", required: true),
        ToolParameter(name: "code", type: "String", description: "Code to execute", required: true)
    ]
    
    func execute(params: [String: Any]) async throws -> String {
        guard let language = params["language"] as? String ?? params["arg0"] as? String,
              let code = params["code"] as? String ?? params["arg1"] as? String else {
            throw ToolBoxError.invalidParams("language and code are required")
        }
        
        // Use BackendService for execution
        let result = try await BackendService.shared.executeCode(code: code, language: language)
        return result.stdout + (result.stderr.isEmpty ? "" : "\nStderr: \(result.stderr)")
    }
}

struct CodeAnalyzeTool: AgentTool {
    let name = "code_analyze"
    let description = "Analyze code for quality and issues"
    let parameters = [
        ToolParameter(name: "code", type: "String", description: "Code to analyze", required: true),
        ToolParameter(name: "language", type: "String", description: "Programming language", required: true)
    ]
    
    func execute(params: [String: Any]) async throws -> String {
        guard let code = params["code"] as? String ?? params["arg0"] as? String,
              let language = params["language"] as? String ?? params["arg1"] as? String else {
            throw ToolBoxError.invalidParams("code and language are required")
        }
        
        let analysis = try await BackendService.shared.analyzeCode(code: code, language: language)
        return """
        Lines: \(analysis.lines)
        Functions: \(analysis.functions.count)
        Classes: \(analysis.classes.count)
        Complexity: \(analysis.complexity ?? 0)
        Issues: \(analysis.issues.count)
        """
    }
}

struct GitStatusTool: AgentTool {
    let name = "git_status"
    let description = "Get git repository status"
    let parameters = [
        ToolParameter(name: "path", type: "String", description: "Repository path", required: true)
    ]
    
    func execute(params: [String: Any]) async throws -> String {
        guard let path = params["path"] as? String ?? params["arg0"] as? String else {
            throw ToolBoxError.invalidParams("path is required")
        }
        
        let status = try await BackendService.shared.getGitStatus(repoPath: path)
        let modified = status.files.filter { $0.status == "M" }.count
        let staged = status.files.filter { $0.status == "A" || $0.status == "MM" }.count
        let untracked = status.files.filter { $0.status == "?" }.count
        
        return """
        Branch: \(status.branch)
        Modified: \(modified) files
        Staged: \(staged) files
        Untracked: \(untracked) files
        Total: \(status.files.count) files changed
        """
    }
}

struct WebFetchTool: AgentTool {
    let name = "web_fetch"
    let description = "Fetch content from a URL"
    let parameters = [
        ToolParameter(name: "url", type: "String", description: "URL to fetch", required: true)
    ]
    
    func execute(params: [String: Any]) async throws -> String {
        guard let urlStr = params["url"] as? String ?? params["arg0"] as? String,
              let url = URL(string: urlStr) else {
            throw ToolBoxError.invalidParams("valid url is required")
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        let content = String(data: data, encoding: .utf8) ?? ""
        
        // Truncate if too long
        if content.count > 5000 {
            return String(content.prefix(5000)) + "\n... (truncated)"
        }
        return content
    }
}

struct ShellCommandTool: AgentTool {
    let name = "shell"
    let description = "Execute shell command (use with caution)"
    let parameters = [
        ToolParameter(name: "command", type: "String", description: "Shell command", required: true),
        ToolParameter(name: "cwd", type: "String", description: "Working directory", required: false)
    ]
    
    func execute(params: [String: Any]) async throws -> String {
        guard let command = params["command"] as? String ?? params["arg0"] as? String else {
            throw ToolBoxError.invalidParams("command is required")
        }
        
        let cwd = params["cwd"] as? String ?? params["arg1"] as? String
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-c", command]
        
        if let cwd = cwd {
            process.currentDirectoryURL = URL(fileURLWithPath: cwd)
        }
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        try process.run()
        process.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        
        if process.terminationStatus != 0 {
            return "Command failed (exit \(process.terminationStatus)): \(output)"
        }
        return output
    }
}
