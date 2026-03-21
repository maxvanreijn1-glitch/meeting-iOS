// WebViewModelTests.swift
// Tests/Unit
//
// Unit tests for WebViewModel state transitions.

import XCTest
import Combine
@testable import Meetingsmanaged

@MainActor
final class WebViewModelTests: XCTestCase {

    private var viewModel: WebViewModel!
    private var cancellables = Set<AnyCancellable>()

    override func setUp() async throws {
        viewModel = WebViewModel(
            configService: .shared,
            networkMonitor: .shared,
            storageService: .shared
        )
    }

    override func tearDown() {
        cancellables.removeAll()
    }

    // MARK: - Tests

    func test_initialState_isNotLoading() {
        XCTAssertFalse(viewModel.isLoading)
    }

    func test_didStartNavigation_setsLoading() {
        let url = URL(string: "https://example.com")
        viewModel.didStartNavigation(url: url)
        XCTAssertTrue(viewModel.isLoading)
        XCTAssertEqual(viewModel.currentURL, url)
        XCTAssertEqual(viewModel.loadingProgress, 0)
    }

    func test_didFinishNavigation_clearsLoading() {
        let url = URL(string: "https://example.com")
        viewModel.didStartNavigation(url: url)
        viewModel.didFinishNavigation(url: url, title: "Example")
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertEqual(viewModel.pageTitle, "Example")
        XCTAssertFalse(viewModel.isOffline)
    }

    func test_progressChanged_updatesProgress() {
        viewModel.progressChanged(0.75)
        XCTAssertEqual(viewModel.loadingProgress, 0.75, accuracy: 0.001)
    }

    func test_titleChanged_updatesTitle() {
        viewModel.titleChanged("My Page")
        XCTAssertEqual(viewModel.pageTitle, "My Page")
    }

    func test_titleChanged_emptyStringIsIgnored() {
        viewModel.titleChanged("Initial")
        viewModel.titleChanged("")
        XCTAssertEqual(viewModel.pageTitle, "Initial")
    }

    func test_navigate_setsPendingURL() {
        let url = URL(string: "https://example.com/page")!
        viewModel.navigate(to: url)
        // When no webView is bound, navigate should set pendingURL
        XCTAssertEqual(viewModel.pendingURL, url)
    }
}
