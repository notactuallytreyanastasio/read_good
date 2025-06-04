import SwiftUI
import AppKit

class StatusBarController: ObservableObject {
    private var statusBar: NSStatusBar
    private var statusItem: NSStatusItem
    private var popover: NSPopover
    
    @Published var isMenuVisible = false
    
    init() {
        statusBar = NSStatusBar.system
        statusItem = statusBar.statusItem(withLength: NSStatusItem.variableLength)
        popover = NSPopover()
        
        setupStatusItem()
        setupPopover()
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
        popover.contentSize = NSSize(width: 400, height: 600)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: StoryMenuView()
                .environmentObject(StoryManager.shared)
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
            
            // Refresh stories when menu opens
            StoryManager.shared.refreshAllStories()
        }
    }
    
    private func hidePopover() {
        popover.performClose(nil)
        isMenuVisible = false
    }
}