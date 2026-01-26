import SwiftUI

struct DesignModeView: View {
    @EnvironmentObject var appState: AppState
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
        .background(appState.appTheme == .transparent || appState.appTheme == .extraClear ? Color.clear : Color(nsColor: .windowBackgroundColor))
    }
}
