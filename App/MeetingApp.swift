// MeetingApp.swift
// meeting-iOS
//
// Main application entry point using modern SwiftUI App protocol.

import SwiftUI

@main
struct MeetingApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentRootView()
                .environmentObject(DependencyContainer.shared.webViewModel)
                .environmentObject(DependencyContainer.shared.networkMonitor)
        }
    }
}
