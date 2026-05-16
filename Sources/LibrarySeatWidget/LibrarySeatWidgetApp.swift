import AppKit
import SwiftUI

@main
struct LibrarySeatWidgetApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var monitor = SeatMonitor.shared

    var body: some Scene {
        MenuBarExtra {
            SeatMenuView()
                .environmentObject(monitor)
        } label: {
            Text(monitor.menuBarTitle)
                .monospacedDigit()
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        SeatMonitor.shared.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        SeatMonitor.shared.stop()
    }
}
