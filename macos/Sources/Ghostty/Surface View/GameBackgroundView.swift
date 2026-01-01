import SwiftUI
import WebKit

#if canImport(AppKit)
import AppKit

/// A SwiftUI wrapper for WKWebView that displays a game background behind the terminal.
/// The game is loaded from a URL and rendered behind the terminal surface.
struct GameBackgroundView: NSViewRepresentable {
    /// The URL to load for the game background
    let url: URL
    
    /// Whether the game should receive mouse events (vs the terminal)
    @Binding var isGameFocused: Bool
    
    func makeNSView(context: Context) -> GameWebView {
        let webView = GameWebView(isGameFocused: $isGameFocused)
        
        // Load the game URL
        let request = URLRequest(url: url)
        webView.load(request)
        
        Ghostty.logger.info("GameBackgroundView: Loading URL \(url.absoluteString)")
        
        return webView
    }
    
    func updateNSView(_ nsView: GameWebView, context: Context) {
        // Update focus state if needed
        nsView.isGameFocused = isGameFocused
        Ghostty.logger.debug("GameWebView: isGameFocused updated to \(isGameFocused)")
    }
}

/// Custom WKWebView subclass that can forward or block mouse events based on game focus state.
/// Keyboard events always pass through to the terminal so keybinds work.
class GameWebView: WKWebView {
    var isGameFocused: Bool = false {
        didSet {
            // Force the view to update its hit testing behavior
            needsDisplay = true
        }
    }
    
    private var isGameFocusedBinding: Binding<Bool>
    
    init(isGameFocused: Binding<Bool>) {
        self.isGameFocusedBinding = isGameFocused
        self.isGameFocused = isGameFocused.wrappedValue
        
        // Configure WKWebView BEFORE initialization
        let config = WKWebViewConfiguration()
        config.preferences = WKPreferences()
        config.preferences.setValue(true, forKey: "developerExtrasEnabled")
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        
        super.init(frame: .zero, configuration: config)
        
        // Make background transparent so terminal can show through if needed
        setValue(false, forKey: "drawsBackground")
        
        // Enable navigation delegate for debugging
        self.navigationDelegate = self
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }
    
    // MARK: - Event Handling
    // We want mouse events when focused, but keyboard should always go to terminal
    
    override func hitTest(_ point: NSPoint) -> NSView? {
        if isGameFocused {
            return super.hitTest(point)
        }
        // Return nil to let events pass through to views behind us
        return nil
    }
    
    // NEVER take keyboard focus - let keyboard events go to the terminal
    // This ensures keybinds like Ctrl+Shift+G still work
    override var acceptsFirstResponder: Bool {
        return false  // Never become first responder, let terminal keep keyboard focus
    }
    
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return isGameFocused
    }
    
    // Forward keyboard events to next responder (terminal)
    override func keyDown(with event: NSEvent) {
        nextResponder?.keyDown(with: event)
    }
    
    override func keyUp(with event: NSEvent) {
        nextResponder?.keyUp(with: event)
    }
    
    override func flagsChanged(with event: NSEvent) {
        nextResponder?.flagsChanged(with: event)
    }
}

// MARK: - WKNavigationDelegate
extension GameWebView: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        Ghostty.logger.info("GameWebView: Started loading")
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        Ghostty.logger.info("GameWebView: Finished loading")
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        Ghostty.logger.error("GameWebView: Failed to load - \(error.localizedDescription)")
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        Ghostty.logger.error("GameWebView: Failed provisional navigation - \(error.localizedDescription)")
    }
}

#endif
