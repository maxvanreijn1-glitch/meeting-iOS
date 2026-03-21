// ContentRootView.swift
// meeting-iOS
//
// Top-level view wired to the dependency container.
// Serves as the single root view passed to the SwiftUI WindowGroup.

import SwiftUI

struct ContentRootView: View {
    var body: some View {
        WebContainerView()
    }
}

// MARK: - Preview

#Preview {
    ContentRootView()
        .environmentObject(DependencyContainer.shared.webViewModel)
        .environmentObject(NetworkMonitor.shared)
}
