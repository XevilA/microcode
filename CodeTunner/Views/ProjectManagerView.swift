import SwiftUI

struct ProjectManagerView: View {
    @StateObject var taskManager = TaskManager.shared
    @State private var selectedListId: UUID?
    @State private var selectedTaskId: UUID?
    
    var body: some View {
        Group {
            if #available(macOS 13.0, *) {
                NavigationSplitView {
                    TaskSidebar(selectedListId: $selectedListId)
                } content: {
                    if let listId = selectedListId {
                        TaskListView(listId: listId, selectedTaskId: $selectedTaskId)
                    } else {
                        Text("Select a List")
                            .foregroundStyle(.secondary)
                    }
                } detail: {
                    detailView
                }
            } else {
                NavigationView {
                    TaskSidebar(selectedListId: $selectedListId)
                    
                    if let listId = selectedListId {
                        TaskListView(listId: listId, selectedTaskId: $selectedTaskId)
                    } else {
                        Text("Select a List")
                            .foregroundColor(.secondary)
                    }
                    
                    detailView
                }
            }
        }
    }
    
    @ViewBuilder
    private var detailView: some View {
        if let listId = selectedListId, let taskId = selectedTaskId {
            TaskInspectorView(listId: listId, taskId: taskId)
        } else {
            if #available(macOS 14.0, *) {
                ContentUnavailableView("No Task Selected", systemImage: "checkmark.circle")
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("No Task Selected")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

// MARK: - Sidebar
struct TaskSidebar: View {
    @EnvironmentObject var taskManager: TaskManager
    @Binding var selectedListId: UUID?
    @State private var showingAddList = false
    @State private var newListName = ""
    
    var body: some View {
        List(selection: $selectedListId) {
            Section(header: Text("My Lists")) {
                lists
            }
        }
        .toolbar {
            Button(action: { showingAddList = true }) {
                Label("Add List", systemImage: "folder.badge.plus")
            }
        }
        .alert("New List", isPresented: $showingAddList) {
            TextField("List Name", text: $newListName)
            Button("Cancel", role: .cancel) { }
            Button("Create") {
                let list = TaskList(name: newListName.isEmpty ? "New List" : newListName)
                taskManager.addList(list)
                newListName = ""
            }
        }
    }
    
    @ViewBuilder
    private var lists: some View {
        ForEach(taskManager.workspace.lists) { list in
            if #available(macOS 13.0, *) {
                NavigationLink(value: list.id) {
                    listRow(for: list)
                }
            } else {
                // Legacy: Use Tagged View for Selection-based List
                listRow(for: list)
                    .tag(list.id)
            }
        }
    }
    
    private func listRow(for list: TaskList) -> some View {
        Label {
            Text(list.name)
        } icon: {
            Image(systemName: list.icon)
                .foregroundColor(list.color)
        }
    }
}

// MARK: - List View
struct TaskListView: View {
    @EnvironmentObject var taskManager: TaskManager
    let listId: UUID
    @Binding var selectedTaskId: UUID?
    @State private var newTaskTitle = ""
    
    var list: TaskList? {
        taskManager.workspace.lists.first(where: { $0.id == listId })
    }
    
    var sortedTasks: [TaskItem] {
        guard let list = list else { return [] }
        // Sort: Not Done first, then priority
        return list.tasks.sorted {
            if $0.status != .done && $1.status == .done { return true }
            if $0.status == .done && $1.status != .done { return false }
            return $0.createdAt > $1.createdAt
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Quick Add
            HStack {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
                TextField("Add Task", text: $newTaskTitle)
                    .textFieldStyle(.plain)
                    .font(.body)
                    .onSubmit {
                        if !newTaskTitle.isEmpty {
                            let task = TaskItem(title: newTaskTitle)
                            taskManager.addTask(task, toListId: listId)
                            newTaskTitle = ""
                        }
                    }
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            
            List(selection: $selectedTaskId) {
                ForEach(sortedTasks) { task in
                    TaskRowView(task: task, listId: listId)
                        .tag(task.id)
                }
            }
            .listStyle(.inset)
        }
        .navigationTitle(list?.name ?? "Tasks")
    }
}

struct TaskRowView: View {
    @EnvironmentObject var taskManager: TaskManager
    let task: TaskItem
    let listId: UUID
    
    var body: some View {
        HStack {
            Button(action: {
                taskManager.toggleCompletion(task, listId: listId)
            }) {
                Image(systemName: task.status == .done ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(task.status == .done ? .green : .secondary)
                    .font(.title3)
            }
            .buttonStyle(.plain)
            
            VStack(alignment: .leading) {
                Text(task.title)
                    .strikethrough(task.status == .done)
                    .foregroundColor(task.status == .done ? .secondary : .primary)
                
                if !task.notes.isEmpty {
                    Text(task.notes)
                        .lineLimit(1)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
            
            if task.priority != .none {
                Image(systemName: task.priority.icon)
                    .foregroundColor(task.priority.color)
            }
            
            if task.isFlagged {
                Image(systemName: "flag.fill")
                    .foregroundColor(.orange)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Inspector
struct TaskInspectorView: View {
    @EnvironmentObject var taskManager: TaskManager
    let listId: UUID
    let taskId: UUID
    
    // Local edits
    @State private var task: TaskItem?
    
    var body: some View {
        Form {
            if let task = task {
                Section {
                    TextField("Title", text: Binding(
                        get: { task.title },
                        set: updateTask { $0.title = $1 }
                    ))
                    .font(.title2)
                    
                    TextEditor(text: Binding(
                        get: { task.notes },
                        set: updateTask { $0.notes = $1 }
                    ))
                    .frame(minHeight: 100)
                    .font(.body)
                }
                
                Section(header: Text("Details")) {
                    Picker("Priority", selection: Binding(
                        get: { task.priority },
                        set: updateTask { $0.priority = $1 }
                    )) {
                        ForEach(TaskItemPriority.allCases) { p in
                            Text(p.rawValue).tag(p)
                        }
                    }
                    
                    Toggle("Flagged", isOn: Binding(
                        get: { task.isFlagged },
                        set: updateTask { $0.isFlagged = $1 }
                    ))
                    
                    DatePicker("Due Date", selection: Binding(
                        get: { task.dueDate ?? Date() },
                        set: updateTask { $0.dueDate = $1 }
                    ), displayedComponents: [.date, .hourAndMinute])
                }
                
                Section(header: Text("Subtasks")) {
                    // Simple subtask implementation
                    ForEach(task.subtasks) { sub in
                        HStack {
                            Image(systemName: sub.isCompleted ? "checkmark.square" : "square")
                            Text(sub.title)
                        }
                    }
                    Button("Add Subtask") {
                        // Logic to add subtask
                        var t = task
                        t.subtasks.append(SubTask(title: "New Item"))
                        taskManager.updateTask(t, inListId: listId)
                    }
                }
                
                Section {
                    Button("Delete Task", role: .destructive) {
                        taskManager.deleteTask(id: taskId, fromListId: listId)
                    }
                }
            } else {
                Text("Task not found")
            }
        }
        .compatGroupedFormStyle()
        .onAppear { loadTask() }
        .onChange(of: taskId) { _ in loadTask() }
        // .onChange(of: taskManager.workspace) { _ in loadTask() } 
    }
    
    func loadTask() {
        if let list = taskManager.workspace.lists.first(where: { $0.id == listId }),
           let t = list.tasks.first(where: { $0.id == taskId }) {
            self.task = t
        } else {
            self.task = nil
        }
    }
    
    func updateTask<T>(_ modifier: @escaping (inout TaskItem, T) -> Void) -> (T) -> Void {
        return { value in
            guard var t = task else { return }
            modifier(&t, value)
            self.task = t
            taskManager.updateTask(t, inListId: listId)
        }
    }
}
