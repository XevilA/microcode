import SwiftUI
import Combine

// MARK: - Models
struct DevTask: Identifiable, Codable {
    let id: String
    var title: String
    var description: String
    var status: TaskStatus
    var priority: TaskPriority
    var branchName: String?
    
    enum TaskStatus: String, Codable, CaseIterable {
        case backlog, ready, in_progress, review, done
        
        var displayName: String {
            switch self {
            case .backlog: return "Backlog"
            case .ready: return "Ready"
            case .in_progress: return "In Progress"
            case .review: return "Review"
            case .done: return "Done"
            }
        }
    }
    
    enum TaskPriority: String, Codable {
        case low, medium, high, critical
        
        var color: Color {
            switch self {
            case .low: return .blue
            case .medium: return .orange
            case .high: return .red
            case .critical: return .purple
            }
        }
    }
}

class TaskViewModel: ObservableObject {
    @Published var tasks: [DevTask] = []
    
    func fetchTasks() {
        guard let url = URL(string: "http://127.0.0.1:3000/api/tasks/list") else { return }
        
        URLSession.shared.dataTask(with: url) { data, _, _ in
            if let data = data {
                // Parse response { "tasks": [...] }
                struct TaskResponse: Decodable {
                    let tasks: [DevTask]
                }
                
                if let response = try? JSONDecoder().decode(TaskResponse.self, from: data) {
                    DispatchQueue.main.async {
                        self.tasks = response.tasks
                    }
                }
            }
        }.resume()
    }
    
    func createTask(title: String) {
        guard let url = URL(string: "http://127.0.0.1:3000/api/tasks/create") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "title": title,
            "project_id": "demo", // Mock
            "parent_id": NSNull() // JSON null
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { data, _, _ in
            if data != nil {
                self.fetchTasks() // Refresh
            }
        }.resume()
    }
}

// MARK: - View
struct TaskDashboardView: View {
    @StateObject var viewModel = TaskViewModel()
    @State private var showingCreate = false
    @State private var showingPalette = false
    @State private var newTaskTitle = ""
    
    var body: some View {
        ZStack {
            HStack(spacing: 0) {
                // Kanban Columns
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 16) {
                        ForEach(DevTask.TaskStatus.allCases, id: \.self) { status in
                            KanbanColumnView(status: status, tasks: viewModel.tasks.filter { $0.status == status })
                        }
                    }
                    .padding()
                }
            }
            .networkBackground()
            .toolbar {
                Button(action: { showingPalette.toggle() }) {
                    Label("Search Tasks", systemImage: "command")
                }
                .help("Command Palette (Cmd+Shift+T)")
                
                Button(action: { showingCreate = true }) {
                    Label("New Task", systemImage: "plus")
                }
            }
            .onAppear {
                viewModel.fetchTasks()
            }
            
            // Command Palette Overlay
            if showingPalette {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture { showingPalette = false }
                
                TaskCommandPalette(viewModel: viewModel, isPresented: $showingPalette)
                    .transition(AnyTransition.move(edge: .top).combined(with: AnyTransition.opacity))
                    .zIndex(1)
            }
        }
    }
}

struct KanbanColumnView: View {
    let status: DevTask.TaskStatus
    let tasks: [DevTask]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text(status.displayName)
                    .font(.headline)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(tasks.count)")
                    .font(.caption)
                    .padding(4)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(4)
            }
            .padding(.horizontal, 4)
            
            // Tasks
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(tasks) { task in
                        TaskCard(task: task)
                    }
                }
            }
        }
        .frame(width: 250)
        .padding()
        .background(Color(nsColor: .windowBackgroundColor))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.secondary.opacity(0.1), lineWidth: 1)
        )
    }
}

struct TaskCard: View {
    let task: DevTask
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(task.title)
                .font(.system(size: 13, weight: .medium))
                .lineLimit(2)
            
            HStack {
                if let branch = task.branchName {
                    HStack(spacing: 4) {
                        Image(systemName: "captions.bubble") // Git icon proxy
                            .font(.system(size: 10))
                        Text(branch)
                            .font(.system(size: 10, design: .monospaced))
                    }
                    .padding(4)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(4)
                }
                
                Spacer()
                
                Circle()
                    .fill(task.priority.color)
                    .frame(width: 8, height: 8)
            }
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

extension View {
    func networkBackground() -> some View {
        self.background(Color(nsColor: .underPageBackgroundColor))
    }
}
