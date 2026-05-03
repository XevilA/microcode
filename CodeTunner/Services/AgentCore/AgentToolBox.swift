//
//  AgentToolBox.swift
//  CodeTunner
//
//  Production-Grade AI Agent ToolBox
//  Unified tool execution with sandbox validation + JSON Schema export
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
    let type: String // "string", "integer", "boolean"
    let description: String
    let required: Bool
}

// MARK: - Agent ToolBox

@MainActor
class AgentToolBox: ObservableObject {
    static let shared = AgentToolBox()
    
    @Published var tools: [String: any AgentTool] = [:]
    @Published var executionHistory: [ToolExecution] = []
    
    /// Workspace root — all file operations are sandboxed to this path
    var workspaceRoot: String? = nil
    
    init() {
        registerBuiltinTools()
    }
    
    private func registerBuiltinTools() {
        register(FileReadTool())
        register(FileWriteTool())
        register(FileSearchTool())
        register(GrepSearchTool())
        register(ReplaceInFileTool())
        register(ListDirectoryTreeTool())
        register(ShellCommandTool())
        register(GitStatusTool())
        register(WebFetchTool())
    }
    
    func register(_ tool: any AgentTool) {
        tools[tool.name] = tool
    }
    
    func execute(_ toolName: String, params: [String: Any]) async throws -> String {
        guard let tool = tools[toolName] else {
            throw ToolBoxError.toolNotFound(toolName)
        }
        
        // Sandbox validation for file operations
        if ["file_read", "file_write", "replace_in_file", "grep_search", "list_directory_tree"].contains(toolName) {
            if let path = params["path"] as? String ?? params["directory"] as? String {
                try validateSandbox(path)
            }
        }
        
        let startTime = Date()
        
        do {
            let result = try await tool.execute(params: params)
            let execution = ToolExecution(toolName: toolName, params: params, result: result, success: true, duration: Date().timeIntervalSince(startTime))
            executionHistory.append(execution)
            
            // Truncate very large outputs
            if result.count > 15000 {
                return String(result.prefix(15000)) + "\n\n... (output truncated at 15K chars)"
            }
            return result
        } catch {
            let execution = ToolExecution(toolName: toolName, params: params, result: error.localizedDescription, success: false, duration: Date().timeIntervalSince(startTime))
            executionHistory.append(execution)
            throw error
        }
    }
    
    // MARK: - Sandbox Validation
    
    private func validateSandbox(_ path: String) throws {
        guard let root = workspaceRoot else { return } // No workspace = no restriction
        let resolved = (path as NSString).standardizingPath
        let rootResolved = (root as NSString).standardizingPath
        guard resolved.hasPrefix(rootResolved) || resolved.hasPrefix("/tmp") else {
            throw ToolBoxError.executionFailed("Path '\(path)' is outside the workspace. Access denied.")
        }
    }
    
    // MARK: - Tool Descriptions (for prompt injection)
    
    var toolDescriptions: String {
        tools.values.sorted(by: { $0.name < $1.name }).map { tool in
            let params = tool.parameters.map { "\($0.name): \($0.type)\($0.required ? " (required)" : "")" }.joined(separator: ", ")
            return "- \(tool.name)(\(params)): \(tool.description)"
        }.joined(separator: "\n")
    }
    
    // MARK: - JSON Schema Export (for native function calling)
    
    func toolSchemas() -> [[String: Any]] {
        tools.values.sorted(by: { $0.name < $1.name }).map { tool in
            var properties: [String: Any] = [:]
            var requiredParams: [String] = []
            
            for param in tool.parameters {
                properties[param.name] = [
                    "type": param.type,
                    "description": param.description
                ] as [String: Any]
                if param.required { requiredParams.append(param.name) }
            }
            
            return [
                "name": tool.name,
                "description": tool.description,
                "parameters": [
                    "type": "object",
                    "properties": properties,
                    "required": requiredParams
                ] as [String: Any]
            ] as [String: Any]
        }
    }
    
    var toolList: [any AgentTool] { Array(tools.values) }
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
    let description = "Read the contents of a file at the given path"
    let parameters = [
        ToolParameter(name: "path", type: "string", description: "Absolute file path to read", required: true)
    ]
    
    func execute(params: [String: Any]) async throws -> String {
        guard let path = params["path"] as? String else {
            throw ToolBoxError.invalidParams("path is required")
        }
        let url = URL(fileURLWithPath: path)
        let content = try String(contentsOf: url, encoding: .utf8)
        // Truncate very large files
        if content.count > 10000 {
            return String(content.prefix(10000)) + "\n\n... (file truncated at 10K chars, total: \(content.count) chars)"
        }
        return content
    }
}

struct FileWriteTool: AgentTool {
    let name = "file_write"
    let description = "Write content to a file, creating it if it doesn't exist"
    let parameters = [
        ToolParameter(name: "path", type: "string", description: "Absolute file path to write", required: true),
        ToolParameter(name: "content", type: "string", description: "Full content to write to the file", required: true)
    ]
    
    func execute(params: [String: Any]) async throws -> String {
        guard let path = params["path"] as? String,
              let content = params["content"] as? String else {
            throw ToolBoxError.invalidParams("path and content are required")
        }
        let url = URL(fileURLWithPath: path)
        // Create parent directories if needed
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try content.write(to: url, atomically: true, encoding: .utf8)
        return "✅ Written \(content.count) chars to \(url.lastPathComponent)"
    }
}

struct ReplaceInFileTool: AgentTool {
    let name = "replace_in_file"
    let description = "Find and replace text in a file. Use this instead of file_write for targeted edits."
    let parameters = [
        ToolParameter(name: "path", type: "string", description: "Absolute file path", required: true),
        ToolParameter(name: "old_text", type: "string", description: "Exact text to find (must match exactly)", required: true),
        ToolParameter(name: "new_text", type: "string", description: "Replacement text", required: true)
    ]
    
    func execute(params: [String: Any]) async throws -> String {
        guard let path = params["path"] as? String,
              let oldText = params["old_text"] as? String,
              let newText = params["new_text"] as? String else {
            throw ToolBoxError.invalidParams("path, old_text, and new_text are required")
        }
        
        let url = URL(fileURLWithPath: path)
        var content = try String(contentsOf: url, encoding: .utf8)
        
        guard content.contains(oldText) else {
            throw ToolBoxError.executionFailed("Could not find the specified text in \(url.lastPathComponent). Make sure old_text matches exactly.")
        }
        
        content = content.replacingOccurrences(of: oldText, with: newText)
        try content.write(to: url, atomically: true, encoding: .utf8)
        
        return "✅ Replaced text in \(url.lastPathComponent)"
    }
}

struct GrepSearchTool: AgentTool {
    let name = "grep_search"
    let description = "Search for a text pattern across files in a directory using grep"
    let parameters = [
        ToolParameter(name: "pattern", type: "string", description: "Search pattern (regex supported)", required: true),
        ToolParameter(name: "directory", type: "string", description: "Directory to search in", required: true),
        ToolParameter(name: "include", type: "string", description: "File glob pattern e.g. '*.swift'", required: false)
    ]
    
    func execute(params: [String: Any]) async throws -> String {
        guard let pattern = params["pattern"] as? String,
              let directory = params["directory"] as? String else {
            throw ToolBoxError.invalidParams("pattern and directory are required")
        }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/grep")
        var args = ["-rn", "--color=never", "-I"] // recursive, line numbers, no color, skip binary
        if let include = params["include"] as? String {
            args.append(contentsOf: ["--include", include])
        }
        // Limit output
        args.append(contentsOf: ["-m", "50"]) // max 50 matches per file
        args.append(pattern)
        args.append(directory)
        process.arguments = args
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe() // discard stderr
        
        try process.run()
        process.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        
        if output.isEmpty {
            return "No matches found for '\(pattern)' in \(directory)"
        }
        
        // Truncate if too many results
        if output.count > 8000 {
            return String(output.prefix(8000)) + "\n... (results truncated)"
        }
        return output
    }
}

struct ListDirectoryTreeTool: AgentTool {
    let name = "list_directory_tree"
    let description = "List the directory structure as a tree, showing files and folders"
    let parameters = [
        ToolParameter(name: "path", type: "string", description: "Directory path to list", required: true),
        ToolParameter(name: "max_depth", type: "integer", description: "Maximum depth (default: 3)", required: false)
    ]
    
    func execute(params: [String: Any]) async throws -> String {
        guard let path = params["path"] as? String else {
            throw ToolBoxError.invalidParams("path is required")
        }
        
        let maxDepth = params["max_depth"] as? Int ?? 3
        let fm = FileManager.default
        let url = URL(fileURLWithPath: path)
        
        guard fm.fileExists(atPath: path) else {
            throw ToolBoxError.executionFailed("Path does not exist: \(path)")
        }
        
        var result = "\(url.lastPathComponent)/\n"
        result += buildTree(at: url, prefix: "", depth: 0, maxDepth: maxDepth, fm: fm)
        return result
    }
    
    private func buildTree(at url: URL, prefix: String, depth: Int, maxDepth: Int, fm: FileManager) -> String {
        guard depth < maxDepth else { return "" }
        
        guard let items = try? fm.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) else { return "" }
        
        let sorted = items.sorted { $0.lastPathComponent < $1.lastPathComponent }
        var result = ""
        
        for (i, item) in sorted.enumerated() {
            let isLast = i == sorted.count - 1
            let connector = isLast ? "└── " : "├── "
            let childPrefix = isLast ? "    " : "│   "
            
            let isDir = (try? item.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            result += "\(prefix)\(connector)\(item.lastPathComponent)\(isDir ? "/" : "")\n"
            
            if isDir {
                result += buildTree(at: item, prefix: prefix + childPrefix, depth: depth + 1, maxDepth: maxDepth, fm: fm)
            }
        }
        return result
    }
}

struct FileSearchTool: AgentTool {
    let name = "file_search"
    let description = "Search for files matching a name pattern in a directory"
    let parameters = [
        ToolParameter(name: "directory", type: "string", description: "Directory to search", required: true),
        ToolParameter(name: "pattern", type: "string", description: "File name pattern (e.g. '*.swift')", required: true)
    ]
    
    func execute(params: [String: Any]) async throws -> String {
        guard let directory = params["directory"] as? String,
              let pattern = params["pattern"] as? String else {
            throw ToolBoxError.invalidParams("directory and pattern are required")
        }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/find")
        process.arguments = [directory, "-name", pattern, "-type", "f", "-maxdepth", "5"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        
        try process.run()
        process.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }
}

struct ShellCommandTool: AgentTool {
    let name = "shell"
    let description = "Execute a shell command. Use for build, test, git, or other CLI operations."
    let parameters = [
        ToolParameter(name: "command", type: "string", description: "Shell command to execute", required: true),
        ToolParameter(name: "cwd", type: "string", description: "Working directory (optional)", required: false)
    ]
    
    func execute(params: [String: Any]) async throws -> String {
        guard let command = params["command"] as? String else {
            throw ToolBoxError.invalidParams("command is required")
        }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-c", command]
        
        if let cwd = params["cwd"] as? String {
            process.currentDirectoryURL = URL(fileURLWithPath: cwd)
        }
        
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        
        try process.run()
        
        // Timeout: 30 seconds
        let deadline = DispatchTime.now() + .seconds(30)
        DispatchQueue.global().asyncAfter(deadline: deadline) {
            if process.isRunning { process.terminate() }
        }
        
        process.waitUntilExit()
        
        let stdout = String(data: stdoutPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let stderr = String(data: stderrPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        
        var output = stdout
        if !stderr.isEmpty { output += "\n[stderr]\n\(stderr)" }
        if process.terminationStatus != 0 { output = "[exit code: \(process.terminationStatus)]\n\(output)" }
        
        // Truncate
        if output.count > 10000 { return String(output.prefix(10000)) + "\n... (truncated)" }
        return output
    }
}

struct GitStatusTool: AgentTool {
    let name = "git_status"
    let description = "Get git status of the current repository"
    let parameters = [
        ToolParameter(name: "path", type: "string", description: "Repository path", required: true)
    ]
    
    func execute(params: [String: Any]) async throws -> String {
        guard let path = params["path"] as? String else {
            throw ToolBoxError.invalidParams("path is required")
        }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["status", "--short"]
        process.currentDirectoryURL = URL(fileURLWithPath: path)
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        try process.run()
        process.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? "No git status available"
    }
}

struct WebFetchTool: AgentTool {
    let name = "web_fetch"
    let description = "Fetch content from a URL"
    let parameters = [
        ToolParameter(name: "url", type: "string", description: "URL to fetch", required: true)
    ]
    
    func execute(params: [String: Any]) async throws -> String {
        guard let urlStr = params["url"] as? String,
              let url = URL(string: urlStr) else {
            throw ToolBoxError.invalidParams("valid url is required")
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        let content = String(data: data, encoding: .utf8) ?? ""
        
        if content.count > 5000 {
            return String(content.prefix(5000)) + "\n... (truncated)"
        }
        return content
    }
}
