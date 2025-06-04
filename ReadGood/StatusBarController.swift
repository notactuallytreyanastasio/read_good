import SwiftUI
import AppKit

@MainActor
class StatusBarController: ObservableObject {
    private var statusBar: NSStatusBar
    private var statusItem: NSStatusItem
    private var popover: NSPopover
    private let storyManager = StoryManager()
    
    @Published var isMenuVisible = false
    
    init() {
        statusBar = NSStatusBar.system
        statusItem = statusBar.statusItem(withLength: NSStatusItem.variableLength)
        popover = NSPopover()
        
        setupStatusItem()
        setupPopover()
        
        // Start periodic refresh and do initial load
        storyManager.startPeriodicRefresh()
        
        // Initial story load
        Task {
            storyManager.refreshAllStories()
        }
    }
    
    private func setupStatusItem() {
        // Create menu bar icon
        if let button = statusItem.button {
            // Use SF Symbol for better macOS integration
            let image = NSImage(systemSymbolName: "doc.text.fill", accessibilityDescription: "ReadGood")
            image?.isTemplate = true
            button.image = image
            button.action = #selector(statusBarButtonClicked(_:))
            button.target = self
            button.toolTip = "ReadGood - Click for stories"
        }
    }
    
    private func setupPopover() {
        // Fixed height for content-based sizing
        let contentHeight: CGFloat = 600 // Enough for ~15 stories + headers/controls
        
        popover.contentSize = NSSize(width: 720, height: contentHeight)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: StoryMenuView()
                .environmentObject(storyManager)
        )
    }
    
    @objc private func statusBarButtonClicked(_ sender: NSStatusBarButton) {
        if popover.isShown {
            hidePopover()
        } else {
            showPopover()
        }
    }
    
    private func showPopover() {
        if let button = statusItem.button {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            isMenuVisible = true
            
            // Only refresh if we have no stories or it's been a while
            Task {
                if storyManager.stories.isEmpty || 
                   storyManager.lastRefresh == nil || 
                   Date().timeIntervalSince(storyManager.lastRefresh!) > 300 { // 5 minutes
                    storyManager.refreshAllStories()
                }
            }
        }
    }
    
    private func hidePopover() {
        popover.performClose(nil)
        isMenuVisible = false
    }
}