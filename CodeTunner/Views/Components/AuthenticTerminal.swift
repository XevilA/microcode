import SwiftUI
import SwiftTerm
import AppKit

struct AuthenticTerminal: NSViewRepresentable {
    var shell: String = "/bin/zsh"
    
    func makeNSView(context: Context) -> LocalProcessTerminalView {
        let terminalView = LocalProcessTerminalView(frame: .zero)
        
        // Configure appearance
        terminalView.configureNativeLook()
        
        // Start shell
        // We use the simpler startProcess API from SwiftTerm which handles PTY
        terminalView.startProcess(executable: shell, args: ["-l"])
        
        return terminalView
    }
    
    func updateNSView(_ nsView: LocalProcessTerminalView, context: Context) {
        // Handle updates if necessary (e.g. font change, theme change)
        // For now, simpler is better.
    }
}

extension LocalProcessTerminalView {
    func configureNativeLook() {
        // Get font from system or use a nice monospaced one
        let font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        
        // SwiftTerm configuration
        self.font = font
        self.nativeBackgroundColor = NSColor.black
        self.nativeForegroundColor = NSColor.white
        
        // Enable mouse reporting for vim/htop
        // SwiftTerm usually handles this by default but good to verify
    }
}
