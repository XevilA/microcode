import SwiftUI

struct CICDPipelineView: View {
    @EnvironmentObject var appState: AppState
    
    // Local state for UI only
    @State private var runs: [WorkflowRun] = []
    @State private var selectedRunId: Int?
    @State private var selectedJob: Job?
    @State private var jobs: [Job] = []
    @State private var logs: String = ""
    @State private var showingSettings = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    // For trigger
    @State private var showingTrigger = false
    @State private var triggerWorkflowId = "main.yml"
    @State private var triggerRef = "main"

    var body: some View {
        CompatHSplitView {
            // Sidebar: Runs List
            VStack(spacing: 0) {
                HStack {
                    Text("Workflows")
                        .font(.headline)
                    Spacer()
                    Button(action: { refreshRuns() }) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(appState.githubToken.isEmpty)
                }
                .padding(10)
                .background(Color(nsColor: .controlBackgroundColor))
                
                if runs.isEmpty && isLoading {
                    ProgressView().padding()
                } else if runs.isEmpty {
                    Text("No runs or not configured")
                        .foregroundColor(.secondary)
                        .padding()
                } else {
                    List(runs, id: \.id, selection: $selectedRunId) { run in
                        RunRow(run: run)
                    }
                    .listStyle(SidebarListStyle())
                    .onChange(of: selectedRunId) { newValue in
                        if let runId = newValue, let run = runs.first(where: { $0.id == runId }) {
                            fetchJobs(for: run)
                        }
                    }
                }
                
                Divider()
                
                Button("Configure") {
                    showingSettings = true
                }
                .padding(10)
            }
            .frame(minWidth: 250, maxWidth: 350)
            
            // Main Content: Job Details & Logs
            VStack(spacing: 0) {
                if let runId = selectedRunId, let run = runs.first(where: { $0.id == runId }) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(run.display_title)
                                .font(.title2)
                                .bold()
                            Text("Branch: \(run.name) • #\(run.run_number)")
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        if let url = URL(string: run.html_url) {
                            Link("Open in Browser", destination: url)
                        }
                    }
                    .padding()
                    .background(Color(nsColor: .controlBackgroundColor))
                    
                    CompatHSplitView {
                        // Jobs List
                        List(jobs) { job in
                            HStack {
                                StatusIcon(status: job.status, conclusion: job.conclusion)
                                Text(job.name)
                                Spacer()
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedJob = job
                                fetchLogs(for: job)
                            }
                            .background(selectedJob?.id == job.id ? Color.blue.opacity(0.1) : Color.clear)
                        }
                        .frame(minWidth: 200)
                        
                        // Logs
                        if selectedJob != nil {
                            ScrollView {
                                Text(logs)
                                    .font(.monospaced(.body)())
                                    .padding()
                                    .textSelection(.enabled)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color.black)
                            .foregroundColor(.white)
                        } else {
                            Text("Select a job to view logs")
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                } else {
                    Text("Select a run to view details")
                        .font(.title)
                        .foregroundColor(.secondary)
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showingTrigger = true }) {
                    Label("Run Workflow", systemImage: "play.fill")
                }
                .disabled(appState.githubToken.isEmpty)
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsSheet(isPresented: $showingSettings)
                .environmentObject(appState)
        }
        .sheet(isPresented: $showingTrigger) {
            TriggerSheet(workflowId: $triggerWorkflowId, ref: $triggerRef, isPresented: $showingTrigger, triggerAction: triggerWorkflow)
        }
        .onAppear {
            if !appState.githubToken.isEmpty && !appState.githubRepo.isEmpty {
                refreshRuns()
            }
        }
    }
    
    func refreshRuns() {
        guard !appState.githubToken.isEmpty else { return }
        isLoading = true
        CICDService.shared.fetchWorkflowRuns(owner: appState.githubOwner, repo: appState.githubRepo, token: appState.githubToken) { result in
            DispatchQueue.main.async {
                isLoading = false
                switch result {
                case .success(let fetchedRuns):
                    self.runs = fetchedRuns
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    func fetchJobs(for run: WorkflowRun) {
        jobs = []
        selectedJob = nil
        logs = ""
        CICDService.shared.fetchJobs(owner: appState.githubOwner, repo: appState.githubRepo, token: appState.githubToken, runId: run.id) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let fetchedJobs):
                    self.jobs = fetchedJobs
                case .failure(let error):
                    print("Error fetching jobs: \(error)")
                }
            }
        }
    }
    
    func fetchLogs(for job: Job) {
        logs = "Loading logs..."
        CICDService.shared.getJobLogs(owner: appState.githubOwner, repo: appState.githubRepo, token: appState.githubToken, jobId: job.id) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let logText):
                    self.logs = logText
                case .failure(let error):
                    self.logs = "Error fetching logs: \(error.localizedDescription)"
                }
            }
        }
    }
    
    func triggerWorkflow() {
        CICDService.shared.triggerWorkflow(owner: appState.githubOwner, repo: appState.githubRepo, token: appState.githubToken, workflowId: triggerWorkflowId, ref: triggerRef) { result in
            DispatchQueue.main.async {
                // Refresh runs after delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    refreshRuns()
                }
            }
        }
    }
}

struct RunRow: View {
    let run: WorkflowRun
    
    var body: some View {
        HStack {
            StatusIcon(status: run.status, conclusion: run.conclusion)
            VStack(alignment: .leading) {
                Text(run.display_title)
                    .lineLimit(1)
                    .font(.body)
                Text("#\(run.run_number) • \(run.name)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct StatusIcon: View {
    let status: String
    let conclusion: String?
    
    var body: some View {
        if status == "completed" {
            if conclusion == "success" {
                Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
            } else if conclusion == "failure" {
                Image(systemName: "xmark.circle.fill").foregroundColor(.red)
            } else {
                Image(systemName: "exclamationmark.circle").foregroundColor(.orange)
            }
        } else {
            ProgressView()
            .scaleEffect(0.5)
            .frame(width: 16, height: 16)
        }
    }
}

struct SettingsSheet: View {
    @EnvironmentObject var appState: AppState
    @Binding var isPresented: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            Text("CI/CD Configuration").font(.headline)
            Form {
                TextField("GitHub Owner", text: $appState.githubOwner)
                TextField("Repository", text: $appState.githubRepo)
                SecureField("Personal Access Token", text: $appState.githubToken)
                Text("Token requires 'repo' scope.").font(.caption).foregroundColor(.secondary)
                
                Divider()
                
                Button(action: {
                    if let folder = appState.workspaceFolder {
                        appState.detectGitRemote(for: folder)
                    }
                }) {
                    HStack {
                        Image(systemName: "arrow.triangle.2.circlepath")
                        Text("Auto-Detect from .git")
                    }
                }
            }
            .padding()
            
            HStack {
                Button("Close") { isPresented = false }
            }
        }
        .frame(width: 400)
        .padding()
    }
}

struct TriggerSheet: View {
    @Binding var workflowId: String
    @Binding var ref: String
    @Binding var isPresented: Bool
    var triggerAction: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Trigger Workflow").font(.headline)
            Form {
                TextField("Workflow Filename", text: $workflowId)
                TextField("Ref (branch/tag)", text: $ref)
            }
            .padding()
            
            HStack {
                Button("Cancel") { isPresented = false }
                Button("Trigger") {
                    triggerAction()
                    isPresented = false
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .frame(width: 300)
        .padding()
    }
}
