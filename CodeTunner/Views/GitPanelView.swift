//
//  GitPanelView.swift
//  CodeTunner
//
//  Improved Git panel with better UX
//

import SwiftUI

struct GitPanelView: View {
    @EnvironmentObject var appState: AppState
    @State private var showGitSettings: Bool = false
    @State private var showCommitSheet: Bool = false
    @State private var commitMessage: String = ""
    @State private var selectedFiles: Set<String> = []
    @State private var expandedSections: Set<String> = ["staged", "unstaged"]
    @State private var isLoading: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            header
            
            Divider()
            
            if let status = appState.gitStatus {
                // Branch Bar
                branchBar(status: status)
                
                Divider()
                
                // Changes List
                ScrollView {
                    VStack(spacing: 0) {
                        // Staged Changes
                        let staged = status.files.filter { $0.status != "untracked" }
                        if !staged.isEmpty {
                            changesSection(title: "Staged Changes", files: staged, icon: "checkmark.circle.fill", color: .green)
                        }
                        
                        // Unstaged/Untracked
                        let unstaged = status.files.filter { $0.status == "untracked" }
                        if !unstaged.isEmpty {
                            changesSection(title: "Untracked Files", files: unstaged, icon: "plus.circle.fill", color: .orange)
                        }
                        
                        if status.files.isEmpty {
                            emptyState
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                Divider()
                
                // Actions
                actionsBar(status: status)
            } else {
                // Not a git repo
                notRepoState
            }
        }
        .sheet(isPresented: $showGitSettings) {
            GitSettingsView()
                .environmentObject(appState)
        }
        .sheet(isPresented: $showCommitSheet) {
            commitSheet
        }
    }
    
    // MARK: - Header
    
    private var header: some View {
        HStack {
            Image(systemName: "arrow.triangle.branch")
                .foregroundColor(.orange)
            
            Text("Source Control")
                .font(.system(size: 11, weight: .semibold))
            
            Spacer()
            
            Button { appState.gitRefresh() } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 10))
            }
            .buttonStyle(.borderless)
            .help("Refresh")
            
            Button { showGitSettings = true } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 10))
            }
            .buttonStyle(.borderless)
            .help("Git Settings")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(nsColor: .controlBackgroundColor))
    }
    
    // MARK: - Branch Bar
    
    private func branchBar(status: GitStatus) -> some View {
        HStack(spacing: 8) {
            // Branch name
            HStack(spacing: 4) {
                Image(systemName: "arrow.triangle.branch")
                    .font(.system(size: 10))
                Text(status.branch)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.accentColor.opacity(0.1))
            .cornerRadius(4)
            
            Spacer()
            
            // Ahead/Behind
            if status.ahead > 0 {
                HStack(spacing: 2) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 8))
                    Text("\(status.ahead)")
                        .font(.system(size: 10))
                }
                .foregroundColor(.green)
            }
            
            if status.behind > 0 {
                HStack(spacing: 2) {
                    Image(systemName: "arrow.down")
                        .font(.system(size: 8))
                    Text("\(status.behind)")
                        .font(.system(size: 10))
                }
                .foregroundColor(.orange)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }
    
    // MARK: - Changes Section
    
    private func changesSection(title: String, files: [GitFileStatus], icon: String, color: Color) -> some View {
        VStack(spacing: 0) {
            // Section Header
            Button {
                withAnimation {
                    if expandedSections.contains(title) {
                        expandedSections.remove(title)
                    } else {
                        expandedSections.insert(title)
                    }
                }
            } label: {
                HStack {
                    Image(systemName: expandedSections.contains(title) ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                        .frame(width: 12)
                    
                    Image(systemName: icon)
                        .font(.system(size: 10))
                        .foregroundColor(color)
                    
                    Text(title)
                        .font(.system(size: 11, weight: .medium))
                    
                    Spacer()
                    
                    Text("\(files.count)")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(4)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
            }
            .buttonStyle(.plain)
            
            // Files
            if expandedSections.contains(title) {
                ForEach(files, id: \.path) { file in
                    fileRow(file: file)
                }
            }
        }
    }
    
    private func fileRow(file: GitFileStatus) -> some View {
        HStack(spacing: 8) {
            // Status icon
            statusIcon(for: file.status)
                .frame(width: 16)
            
            // File name
            Text(file.path.components(separatedBy: "/").last ?? file.path)
                .font(.system(size: 11))
                .lineLimit(1)
            
            Spacer()
            
            // Directory
            if file.path.contains("/") {
                Text(file.path.components(separatedBy: "/").dropLast().joined(separator: "/"))
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 12)
        .padding(.leading, 24)
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            // Open file
            if let folder = appState.workspaceFolder {
                let url = folder.appendingPathComponent(file.path)
                Task {
                    await appState.loadFile(url: url)
                }
            }
        }
    }
    
    @ViewBuilder
    private func statusIcon(for status: String) -> some View {
        switch status {
        case "added":
            Text("A")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(.green)
        case "modified":
            Text("M")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(.orange)
        case "deleted":
            Text("D")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(.red)
        case "renamed":
            Text("R")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(.blue)
        default:
            Text("U")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 32))
                .foregroundColor(.green)
            
            Text("No changes")
                .font(.system(size: 12, weight: .medium))
            
            Text("Your working tree is clean")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
    
    private var notRepoState: some View {
        VStack(spacing: 16) {
            Image(systemName: "arrow.triangle.branch")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            
            Text("Not a Git Repository")
                .font(.headline)
            
            Text("Initialize a repository to track changes")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Button("Initialize Repository") {
                initRepo()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    // MARK: - Actions Bar
    
    private func actionsBar(status: GitStatus) -> some View {
        HStack(spacing: 8) {
            // Commit
            Button {
                showCommitSheet = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle")
                    Text("Commit")
                }
                .font(.system(size: 11))
            }
            .buttonStyle(.borderedProminent)
            .disabled(status.files.isEmpty)
            
            // Push
            Button {
                appState.gitPush()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up")
                    if status.ahead > 0 {
                        Text("\(status.ahead)")
                    }
                }
                .font(.system(size: 11))
            }
            .buttonStyle(.bordered)
            .disabled(status.ahead == 0)
            
            // Pull
            Button {
                appState.gitPull()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.down")
                    if status.behind > 0 {
                        Text("\(status.behind)")
                    }
                }
                .font(.system(size: 11))
            }
            .buttonStyle(.bordered)
            
            Spacer()
            
            // More actions
            Menu {
                Button("Fetch") { fetch() }
                Button("Stash") { stash() }
                Button("Stash Pop") { stashPop() }
                Divider()
                Button("Discard All Changes") { discardAll() }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 14))
            }
            .menuStyle(.borderlessButton)
            .frame(width: 24)
        }
        .padding(12)
    }
    
    // MARK: - Commit Sheet
    
    private var commitSheet: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Commit Changes")
                    .font(.headline)
                Spacer()
                Button { showCommitSheet = false } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            
            // Message input
            VStack(alignment: .leading, spacing: 6) {
                Text("Commit Message")
                    .font(.subheadline)
                
                TextEditor(text: $commitMessage)
                    .font(.system(size: 12, design: .monospaced))
                    .frame(height: 80)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.secondary.opacity(0.3))
                    )
            }
            
            // Quick messages
            HStack {
                Text("Quick:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                ForEach(["fix:", "feat:", "docs:", "refactor:"], id: \.self) { prefix in
                    Button(prefix) {
                        commitMessage = prefix + " "
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            
            HStack {
                Button("Cancel") { showCommitSheet = false }
                    .buttonStyle(.bordered)
                
                Spacer()
                
                Button("Commit") {
                    doCommit()
                }
                .buttonStyle(.borderedProminent)
                .disabled(commitMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 400)
    }
    
    // MARK: - Actions
    
    private func initRepo() {
        guard let folder = appState.workspaceFolder else { return }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["init"]
        process.currentDirectoryURL = folder
        
        try? process.run()
        process.waitUntilExit()
        
        appState.gitRefresh()
    }
    
    private func doCommit() {
        guard !commitMessage.isEmpty else { return }
        
        Task {
            await appState.commitChanges(message: commitMessage)
            await MainActor.run {
                commitMessage = ""
                showCommitSheet = false
                appState.gitRefresh()
            }
        }
    }
    
    private func fetch() {
        guard let folder = appState.workspaceFolder else { return }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["fetch", "--all"]
        process.currentDirectoryURL = folder
        
        try? process.run()
        process.waitUntilExit()
        
        appState.gitRefresh()
    }
    
    private func stash() {
        guard let folder = appState.workspaceFolder else { return }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["stash"]
        process.currentDirectoryURL = folder
        
        try? process.run()
        process.waitUntilExit()
        
        appState.gitRefresh()
    }
    
    private func stashPop() {
        guard let folder = appState.workspaceFolder else { return }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["stash", "pop"]
        process.currentDirectoryURL = folder
        
        try? process.run()
        process.waitUntilExit()
        
        appState.gitRefresh()
    }
    
    private func discardAll() {
        guard let folder = appState.workspaceFolder else { return }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["checkout", "--", "."]
        process.currentDirectoryURL = folder
        
        try? process.run()
        process.waitUntilExit()
        
        appState.gitRefresh()
    }
}

#Preview {
    GitPanelView()
        .environmentObject(AppState())
        .frame(width: 280, height: 400)
}
