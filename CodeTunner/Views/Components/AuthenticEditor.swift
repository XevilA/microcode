import SwiftUI
import AppKit
import CodeTunnerSupport

struct AuthenticEditor: NSViewRepresentable {
    @Binding var text: String
    var language: String
    var font: NSFont = .monospacedSystemFont(ofSize: 14, weight: .regular)
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        
        // Create the text system stack manually for full control
        let textStorage = NSTextStorage()
        let layoutManager = NSLayoutManager()
        textStorage.addLayoutManager(layoutManager)
        
        let textContainer = NSTextContainer(size: CGSize(width: scrollView.contentSize.width, height: CGFloat.greatestFiniteMagnitude))
        textContainer.widthTracksTextView = true
        layoutManager.addTextContainer(textContainer)
        
        let textView = NSTextView(frame: .zero, textContainer: textContainer)
        textView.autoresizingMask = [.width, .height]
        textView.delegate = context.coordinator
        
        // Configure Editor Properties
        textView.isRichText = false // Plain text mode for code
        textView.allowsUndo = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.font = font
        textView.backgroundColor = PlaygroundsColors.background
        textView.textColor = PlaygroundsColors.text
        textView.insertionPointColor = .white
        textView.selectedTextAttributes = [
            .backgroundColor: NSColor.selectedTextBackgroundColor,
            .foregroundColor: NSColor.white
        ]
        
        // Set initial text
        textView.string = text
        
        // Setup Line Numbers Ruler (Native ObjC++)
        let rulerView = AuthenticLineNumberRuler(scrollView: scrollView, orientation: .verticalRuler)
        scrollView.verticalRulerView = rulerView
        scrollView.hasVerticalRuler = true
        scrollView.rulersVisible = true
        
        // Initial highlight
        context.coordinator.highlight(textView.textStorage, language: language)
        
        scrollView.documentView = textView
        
        // Update Coordinator with the text storage to observe changes if needed
        // but delegate textDidChange is enough for binding updates.
        
        return scrollView
    }
    
    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }
        
        if textView.string != text {
            // Keep selection if possible
            let selectedRanges = textView.selectedRanges
            textView.string = text
            // Highlight again because replacing string clears attributes
            context.coordinator.highlight(textView.textStorage, language: language)
            
            // Restore selection if valid
            if let firstRange = selectedRanges.first?.rangeValue,
               firstRange.upperBound <= text.count {
                textView.selectedRanges = selectedRanges
            }
        }
        
        // Update Helper: Apply Theme to Ruler
        if let ruler = nsView.verticalRulerView as? AuthenticLineNumberRuler {
            let theme = ThemeManager.shared
            ruler.backgroundColor = theme.editorGutterColor
            ruler.textColor = theme.editorGutterTextColor
            ruler.separatorColor = theme.editorForegroundColor.withAlphaComponent(0.1)
            // Force redraw if needed
            ruler.needsDisplay = true
        }
        
        // Update language if changed (re-highlight)
        if context.coordinator.currentLanguage != language {
            context.coordinator.currentLanguage = language
            context.coordinator.highlight(textView.textStorage, language: language)
        }
    }
    
    public class Coordinator: NSObject, NSTextViewDelegate {
        var parent: AuthenticEditor
        var currentLanguage: String
        
        // The Brain (Native ObjC++)
        var languageCore: AuthenticLanguageCore?
        
        init(_ parent: AuthenticEditor) {
            self.parent = parent
            self.currentLanguage = parent.language
            super.init()
            
            // Initialize Core
            self.languageCore = AuthenticLanguageCore(language: currentLanguage)
        }
        
        public func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            
            // 1. Update Binding
            parent.text = textView.string
            
            // 2. Update Core (The Brain)
            languageCore?.updateSource(textView.string)
            
            // 3. Highlight (The Eyes) -> Ask Core for tokens
            highlight(textView.textStorage, language: currentLanguage)
            
            // 4. Invalidate ruler
            textView.enclosingScrollView?.verticalRulerView?.needsDisplay = true
        }
        
        func highlight(_ textStorage: NSTextStorage?, language: String) {
            guard let textStorage = textStorage else { return }
            
            // Re-init core if language changed
            if language != currentLanguage || languageCore == nil {
                currentLanguage = language
                languageCore = AuthenticLanguageCore(language: language)
                languageCore?.updateSource(textStorage.string)
            }
            
            guard let core = languageCore else { return }
            
            // Ensure core is up to date (idempotent if already updated)
            core.updateSource(textStorage.string)
            
            // Get Native Tokens
            let tokens = core.tokens() ?? []
            
            // Apply attributes
            textStorage.beginEditing()
            let strLength = textStorage.length
            let fullRange = NSRange(location: 0, length: strLength)
            
            // Reset base
            textStorage.removeAttribute(.foregroundColor, range: fullRange)
            textStorage.addAttributes([
                .foregroundColor: PlaygroundsColors.text,
                .font: parent.font
            ], range: fullRange)
            
            // Apply token colors
            applyNativeTokens(tokens, to: textStorage)
            
            // Apply Hex Colors (Feature overlay)
            applyHexColorHighlighting(to: textStorage)
            
            textStorage.endEditing()
        }
        
        private func applyNativeTokens(_ tokens: [AuthenticToken], to storage: NSTextStorage) {
            let strLen = storage.length
            
            for token in tokens {
                let range = token.range
                if range.location + range.length <= strLen {
                    let color = colorForTokenType(token.type)
                    storage.addAttribute(.foregroundColor, value: color, range: range)
                }
            }
        }
        
        private func applyHexColorHighlighting(to textStorage: NSTextStorage) {
            let string = textStorage.string
            let fullRange = NSRange(location: 0, length: textStorage.length)
            let hexPattern = "#([A-Fa-f0-9]{6}|[A-Fa-f0-9]{3})\\b"
            
            if let regex = try? NSRegularExpression(pattern: hexPattern, options: []) {
                regex.enumerateMatches(in: string, options: [], range: fullRange) { match, _, _ in
                    guard let matchRange = match?.range else { return }
                    let hexString = (string as NSString).substring(with: matchRange)
                    
                    if let color = NSColor(hexString: hexString) {
                        textStorage.addAttribute(.backgroundColor, value: color, range: matchRange)
                        
                        // Contrast text
                        if let componentColor = color.usingColorSpace(.genericRGB) {
                             let brightness = ((componentColor.redComponent * 299) + (componentColor.greenComponent * 587) + (componentColor.blueComponent * 114)) / 1000
                             let textColor = (brightness > 0.5) ? NSColor.black : NSColor.white
                             textStorage.addAttribute(.foregroundColor, value: textColor, range: matchRange)
                        }
                    }
                }
            }
        }
        
        private func colorForTokenType(_ type: AuthenticTokenType) -> NSColor {
            switch type {
            case .keyword, .keywordControl, .keywordModifier: return PlaygroundsColors.keyword
            case .keywordDeclaration: return PlaygroundsColors.keyword
            case .string: return PlaygroundsColors.string
            case .number: return PlaygroundsColors.number
            case .comment: return PlaygroundsColors.comment
            case .type: return PlaygroundsColors.type
            case .function: return PlaygroundsColors.function
            case .identifier: return PlaygroundsColors.text
            case .operator: return PlaygroundsColors.text
            case .punctuation: return PlaygroundsColors.text
            case .preprocessor: return PlaygroundsColors.keyword 
            case .URL: return PlaygroundsColors.string
            case .unknown: return PlaygroundsColors.text
            @unknown default: return PlaygroundsColors.text
            }
        }
    }
}

// Helper for Color Parsing
extension NSColor {
    convenience init?(hexString: String) {
        var cString: String = hexString.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if (cString.hasPrefix("#")) {
            cString.remove(at: cString.startIndex)
        }
        
        if ((cString.count) != 6 && (cString.count) != 3) {
            return nil
        }
        
        // Expansion of 3-digit hex
        if cString.count == 3 {
            let r = cString[cString.startIndex]
            let g = cString[cString.index(cString.startIndex, offsetBy: 1)]
            let b = cString[cString.index(cString.startIndex, offsetBy: 2)]
            cString = "\(r)\(r)\(g)\(g)\(b)\(b)"
        }
        
        var rgbValue: UInt64 = 0
        Scanner(string: cString).scanHexInt64(&rgbValue)
        
        self.init(
            red: CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0,
            green: CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0,
            blue: CGFloat(rgbValue & 0x0000FF) / 255.0,
            alpha: CGFloat(1.0)
        )
    }
}

