import SwiftUI
import UserNotifications

@main
struct ReadGoodApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var dataController = DataController()
    @StateObject private var storyManager = StoryManager()
    
    var body: some Scene {
        // Menu bar app - no main window
        Settings {
            SettingsView()
                .environment(\.managedObjectContext, dataController.container.viewContext)
                .environmentObject(storyManager)
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBarController: StatusBarController?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide dock icon - menu bar only app
        NSApp.setActivationPolicy(.accessory)
        
        // Create menu bar controller
        statusBarController = StatusBarController()
        
        // Request notification permissions
        requestNotificationPermissions()
    }
    
    private func requestNotificationPermissions() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if granted {
                print("Notification permissions granted")
            }
        }
    }
}