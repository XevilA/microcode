import Foundation
import SwiftUI
import AppKit

enum LoaderError: Error {
    case fileNotFound
    case dlopenFailed(String)
    case symbolNotFound(String)
}

final class ModuleLoader {
    
    /// Loads a dylib and returns the SwiftUI View
    func loadView(from dylibPath: String) throws -> AnyView {
        guard FileManager.default.fileExists(atPath: dylibPath) else {
            throw LoaderError.fileNotFound
        }
        
        // 1. dlopen
        // RTLD_NOW: Locate all symbols immediately
        // RTLD_LOCAL: Symbols are not made available to other libs (avoids collisions)
        guard let handle = dlopen(dylibPath, RTLD_NOW | RTLD_LOCAL) else {
            let error = String(cString: dlerror())
            throw LoaderError.dlopenFailed(error)
        }
        
        // 2. dlsym "makePreview"
        // We expect the user to expose: @_cdecl("makePreview")
        let symbolName = "makePreview"
        guard let symbol = dlsym(handle, symbolName) else {
            throw LoaderError.symbolNotFound(symbolName)
        }
        
        // 3. Cast to function pointer
        typealias MakePreviewFunction = @convention(c) () -> UnsafeMutableRawPointer
        let makePreview = unsafeBitCast(symbol, to: MakePreviewFunction.self)
        
        // 4. Invoke and bridge back to Swift
        // The dylib function must return Unmanaged<NSViewController>
        let opaquePointer = makePreview()
        let viewController = Unmanaged<NSViewController>.fromOpaque(opaquePointer).takeRetainedValue()
        
        // We can extract the view if needed, or just return the VC
        // For this method signature, we wrap it in AnyView for now if we want to keep signature, 
        // OR we change signature to return NSViewController. 
        // Let's wrapping the VC's view into AnyView using NSViewControllerRepresentable (or just using the view directly via special handling).
        // For simplicity in this step, let's return NSViewController. 
        
        // But the function signature says -> AnyView.
        // We can use NSViewControllerRepresentable to wrap the VC back to SwiftUI.
        
        return AnyView(ViewControllerWrapper(controller: viewController))
    }
}

// Minimal wrapper to convert NSViewController back to SwiftUI View
struct ViewControllerWrapper: NSViewControllerRepresentable {
    let controller: NSViewController
    func makeNSViewController(context: Context) -> NSViewController { controller }
    func updateNSViewController(_ nsViewController: NSViewController, context: Context) {}
}
