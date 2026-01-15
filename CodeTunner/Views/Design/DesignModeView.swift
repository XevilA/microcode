import SwiftUI

struct DesignModeView: View {
    @StateObject private var designStore = DesignStore()
    
    var body: some View {
        VStack(spacing: 0) {
            // Top Toolbar
            DesignToolbar()
                .zIndex(1)
            
            Divider()
            
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    // Left Layers Panel
                    DesignLayersPanel()
                        .frame(width: 200)
                    
                    Divider()
                    
                    // Main Canvas
                    DesignCanvasView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                    Divider()
                    
                    // Right Inspector
                    PropertiesInspector()
                        .frame(width: 260)
                        .background(Color(nsColor: .controlBackgroundColor))
                }
            }
        }
        .environmentObject(designStore)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
