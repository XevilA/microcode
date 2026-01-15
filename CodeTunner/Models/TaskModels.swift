import Foundation
import SwiftUI

// MARK: - Enums
enum TaskStatus: String, Codable, CaseIterable, Identifiable {
    case todo = "To Do"
    case doing = "Doing"
    case done = "Done"
    
    var id: String { rawValue }
    
    var color: Color {
        switch self {
        case .todo: return .secondary
        case .doing: return .blue
        case .done: return .green
        }
    }
}

enum TaskItemPriority: String, Codable, CaseIterable, Identifiable {
    case none = "None"
    case low = "Low"
    case medium = "Medium"
    case high = "High"
    case urgent = "Urgent"
    
    var id: String { rawValue }
    
    var color: Color {
        switch self {
        case .none: return .secondary
        case .low: return .green
        case .medium: return .blue
        case .high: return .orange
        case .urgent: return .red
        }
    }
    
    var icon: String {
        switch self {
        case .none: return "minus"
        case .low: return "arrow.down"
        case .medium: return "equal"
        case .high: return "arrow.up"
        case .urgent: return "exclamationmark.3"
        }
    }
}

// MARK: - Core Models

struct SubTask: Identifiable, Codable {
    var id = UUID()
    var title: String
    var isCompleted: Bool = false
}

struct TaskItem: Identifiable, Codable, Hashable {
    static func == (lhs: TaskItem, rhs: TaskItem) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    var id = UUID()
    var title: String
    var notes: String = "" // Markdown supported
    
    // Workflow
    var status: TaskStatus = .todo
    var priority: TaskItemPriority = .none
    var isFlagged: Bool = false
    
    // Dates
    var createdAt = Date()
    var dueDate: Date?
    var completedAt: Date?
    
    // Hierarchy
    var subtasks: [SubTask] = []
    var tags: [String] = []
    
    // Obsidian/Lark features
    var assignee: String? // simple string for now
    var attachments: [String] = [] // Paths
}

struct TaskList: Identifiable, Codable {
    var id = UUID()
    var name: String
    var icon: String = "list.bullet"
    var colorHex: String = "#007AFF"
    var tasks: [TaskItem] = []
    
    var color: Color {
        Color(hex: colorHex) ?? .blue
    }
}

struct TaskWorkspace: Codable {
    var lists: [TaskList]
    
    static func defaultWorkspace() -> TaskWorkspace {
        return TaskWorkspace(lists: [
            TaskList(name: "Inbox", icon: "tray", colorHex: "#A2A2A2"),
            TaskList(name: "Projects", icon: "folder", colorHex: "#5856D6"),
            TaskList(name: "Personal", icon: "person", colorHex: "#FF2D55")
        ])
    }
}

// Color extension moved to Extensions/ColorExtensions.swift
