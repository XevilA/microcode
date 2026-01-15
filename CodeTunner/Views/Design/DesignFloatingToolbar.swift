import SwiftUI

struct DesignFloatingToolbar: View {
    @EnvironmentObject var designStore: DesignStore
    
    var body: some View {
        HStack(spacing: 8) {
            // Pointers
            ToolIcon(active: designStore.currentTool == .select, icon: "cursorarrow", tooltip: "Move (V)") { designStore.currentTool = .select }
            
            // Frame Menu
            Menu {
                Button("iPhone 16 Pro") { addFrame(.iPhone16Pro) }
                Button("iPhone 16 Pro Max") { addFrame(.iPhone16ProMax) }
                Divider()
                Button("iPad Air") { addFrame(.iPadAir) }
                Button("iPad Pro 12.9") { addFrame(.iPadPro12_9) }
                Divider()
                Button("Desktop") { addFrame(.desktop) }
            } label: {
                Image(systemName: "number")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(designStore.currentTool == .frame ? .blue : .primary)
                    .frame(width: 32, height: 32)
                    .background(designStore.currentTool == .frame ? Color.blue.opacity(0.15) : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            
            Divider().frame(height: 20)
            
            // Shapes
            ToolIcon(active: designStore.currentTool == .rectangle, icon: "square", tooltip: "Rectangle (R)") { designStore.currentTool = .rectangle }
            ToolIcon(active: designStore.currentTool == .ellipse, icon: "circle", tooltip: "Ellipse (O)") { designStore.currentTool = .ellipse }
            ToolIcon(active: designStore.currentTool == .line, icon: "line.diagonal", tooltip: "Line (L)") { designStore.currentTool = .line }
            ToolIcon(active: designStore.currentTool == .text, icon: "textformat", tooltip: "Text (T)") { designStore.currentTool = .text }
            
            Divider().frame(height: 20)
            
            // Actions
            Button(action: { designStore.deleteSelection() }) {
                Image(systemName: "trash")
                    .font(.system(size: 16))
                    .foregroundColor(.red)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            .help("Delete Selection")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.regularMaterial)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 5)
        .overlay(
            Capsule().stroke(Color.white.opacity(0.2), lineWidth: 0.5)
        )
    }
    
    private func addFrame(_ type: DesignDeviceType) {
        let frame = DesignElement.createFrame(type: type)
        designStore.addElement(frame)
        designStore.currentTool = .select
    }
}

struct ToolIcon: View {
    var active: Bool
    var icon: String
    var tooltip: String
    var action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(active ? .blue : .primary)
                .frame(width: 32, height: 32)
                .background(active ? Color.blue.opacity(0.15) : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .help(tooltip)
    }
}
