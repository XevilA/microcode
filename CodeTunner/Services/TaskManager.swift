import Foundation
import Combine

class TaskManager: ObservableObject {
    static let shared = TaskManager()
    
    @Published var workspace: TaskWorkspace
    
    private let savePath: URL
    
    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("CodeTunner")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.savePath = dir.appendingPathComponent("tasks_v2.json")
        
        // Load or Create Default
        if let data = try? Data(contentsOf: savePath),
           let saved = try? JSONDecoder().decode(TaskWorkspace.self, from: data) {
            self.workspace = saved
        } else {
            // Try migrate old v1
            let oldPath = dir.appendingPathComponent("tasks.json")
            if let oldData = try? Data(contentsOf: oldPath),
               let oldBoard = try? JSONDecoder().decode(ProjectBoard.self, from: oldData) {
                // Migration logic: Flatten columns into "Inbox" or "Migrated"
                var inbox = TaskList(name: "Migrated Project", icon: "arrow.triangle.merge")
                for col in oldBoard.columns {
                    inbox.tasks.append(contentsOf: col.tasks)
                }
                var newWS = TaskWorkspace.defaultWorkspace()
                newWS.lists.insert(inbox, at: 0)
                self.workspace = newWS
            } else {
                self.workspace = TaskWorkspace.defaultWorkspace()
            }
        }
    }
    
    func save() {
        if let data = try? JSONEncoder().encode(workspace) {
            try? data.write(to: savePath)
        }
    }
    
    // CRUD
    func addList(_ list: TaskList) {
        workspace.lists.append(list)
        save()
    }
    
    func addTask(_ task: TaskItem, toListId listId: UUID) {
        if let index = workspace.lists.firstIndex(where: { $0.id == listId }) {
            workspace.lists[index].tasks.append(task)
            save()
        }
    }
    
    func updateTask(_ task: TaskItem, inListId listId: UUID) {
        if let listIndex = workspace.lists.firstIndex(where: { $0.id == listId }) {
            if let taskIndex = workspace.lists[listIndex].tasks.firstIndex(where: { $0.id == task.id }) {
                workspace.lists[listIndex].tasks[taskIndex] = task
                save()
            }
        }
    }
    
    func deleteTask(id: UUID, fromListId listId: UUID) {
        if let listIndex = workspace.lists.firstIndex(where: { $0.id == listId }) {
            workspace.lists[listIndex].tasks.removeAll(where: { $0.id == id })
            save()
        }
    }
    
    func toggleCompletion(_ task: TaskItem, listId: UUID) {
        var updated = task
        if updated.status == .done {
            updated.status = .todo
            updated.completedAt = nil
        } else {
            updated.status = .done
            updated.completedAt = Date()
        }
        updateTask(updated, inListId: listId)
    }
}

// Temporary shim for old ProjectBoard if needed for compilation elsewhere,
// though we should fix the views next.
struct ProjectBoard: Codable {
    var name: String = ""
    var columns: [KanbanColumn] = []
}
struct KanbanColumn: Codable {
    var status: TaskStatus = .todo
    var tasks: [TaskItem] = []
}
