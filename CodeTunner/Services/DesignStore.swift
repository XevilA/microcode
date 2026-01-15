import SwiftUI
import Combine

@MainActor
class DesignStore: ObservableObject {
    @Published var project: DesignProject
    @Published var activePageId: UUID
    @Published var selection: Set<UUID> = []
    
    // Canvas State
    @Published var zoomLevel: CGFloat = 1.0
    @Published var panOffset: CGSize = .zero
    
    // Tool
    @Published var currentTool: DesignTool = .select
    
    enum DesignTool {
        case select, hand, frame
        // Shapes
        case rectangle, ellipse, roundedRect, star, polygon, line, arrow
        // GUI Tools
        case button, label, textfield, checkbox, switchToggle, slider, progress
        case text, image
        // Advanced
        case card, list, navigationBar, tabBar
        // New
        case avatar, badge, radioButton, tooltip, menu, modal, divider
    }
    
    init() {
        let page1 = DesignPage(name: "Page 1", elements: [])
        self.project = DesignProject(name: "New Design", pages: [page1], activePageId: page1.id)
        self.activePageId = page1.id
    }
    
    // MARK: - Element Management
    
    func addElement(_ element: DesignElement) {
        if let index = project.pages.firstIndex(where: { $0.id == activePageId }) {
            project.pages[index].elements.append(element)
            selection = [element.id]
        }
    }
    
    func updateElement(_ element: DesignElement) {
        if let pageIndex = project.pages.firstIndex(where: { $0.id == activePageId }) {
            if let elIndex = project.pages[pageIndex].elements.firstIndex(where: { $0.id == element.id }) {
                project.pages[pageIndex].elements[elIndex] = element
            }
        }
    }
    
    func deleteSelection() {
        guard let pageIndex = project.pages.firstIndex(where: { $0.id == activePageId }) else { return }
        // Clear selection first to avoid UI trying to render deleted items
        let itemsToDelete = selection
        selection = []
        
        project.pages[pageIndex].elements.removeAll(where: { itemsToDelete.contains($0.id) })
    }
    
    // MARK: - Helpers
    
    var activePage: DesignPage? {
        project.pages.first(where: { $0.id == activePageId })
    }
    
    func selectedElement() -> DesignElement? {
        guard let id = selection.first else { return nil }
        return activePage?.elements.first(where: { $0.id == id })
    }
}
