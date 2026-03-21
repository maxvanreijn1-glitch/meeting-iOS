// WebContainerView.swift
// meeting-iOS
//
// Root view for the WebView feature.
// Composes WebViewRepresentable with navigation bar, toolbar, offline page, and loading progress.

import SwiftUI

struct WebContainerView: View {

    // MARK: - Dependencies

    @EnvironmentObject private var viewModel: WebViewModel
    @EnvironmentObject private var networkMonitor: NetworkMonitor

    private let configService = ConfigService.shared
    private let jsService = JSBridgeService()

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                // Main WebView
                webContent
                    .ignoresSafeArea(edges: .bottom)

                // Loading progress bar
                if viewModel.isLoading {
                    LoadingView(progress: viewModel.loadingProgress)
                        .transition(.opacity)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { navigationToolbar }
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }

    // MARK: - Web content

    @ViewBuilder
    private var webContent: some View {
        if viewModel.isOffline {
            OfflineView {
                viewModel.reload()
            }
            .transition(.opacity)
        } else {
            WebViewRepresentable(
                viewModel: viewModel,
                configService: configService,
                jsService: jsService
            )
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var navigationToolbar: some ToolbarContent {
        // Leading: back / forward
        ToolbarItemGroup(placement: .navigationBarLeading) {
            Button {
                viewModel.goBack()
            } label: {
                Image(systemName: "chevron.left")
            }
            .disabled(!viewModel.canGoBack)

            Button {
                viewModel.goForward()
            } label: {
                Image(systemName: "chevron.right")
            }
            .disabled(!viewModel.canGoForward)
        }

        // Center: page title
        ToolbarItem(placement: .principal) {
            Text(viewModel.pageTitle.isEmpty ? configService.appName : viewModel.pageTitle)
                .font(.headline)
                .lineLimit(1)
        }

        // Trailing: reload / stop
        ToolbarItem(placement: .navigationBarTrailing) {
            if viewModel.isLoading {
                Button {
                    viewModel.stopLoading()
                } label: {
                    Image(systemName: "xmark")
                }
            } else {
                Button {
                    viewModel.reload()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    WebContainerView()
        .environmentObject(DependencyContainer.shared.webViewModel)
        .environmentObject(NetworkMonitor.shared)
}
