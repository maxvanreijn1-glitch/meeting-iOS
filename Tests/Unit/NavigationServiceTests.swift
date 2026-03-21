// NavigationServiceTests.swift
// Tests/Unit
//
// Unit tests for NavigationService URL decision logic.

import XCTest
@testable import Meetingsmanaged

final class NavigationServiceTests: XCTestCase {

    private var service: NavigationService!

    override func setUp() {
        super.setUp()
        service = NavigationService()
    }

    // MARK: - Tests

    func test_allowsHTTPUrl() {
        let url = URL(string: "https://www.meetings-managed.com/dashboard")!
        let decision = service.decide(for: url, isNewWindow: false)
        XCTAssertEqual(decision, .allow)
    }

    func test_opensMailtoExternal() {
        let url = URL(string: "mailto:test@example.com")!
        let decision = service.decide(for: url, isNewWindow: false)
        XCTAssertEqual(decision, .openExternal)
    }

    func test_opensTelExternal() {
        let url = URL(string: "tel:+31612345678")!
        let decision = service.decide(for: url, isNewWindow: false)
        XCTAssertEqual(decision, .openExternal)
    }

    func test_allowsAboutBlank() {
        let url = URL(string: "about:blank")!
        let decision = service.decide(for: url, isNewWindow: false)
        XCTAssertEqual(decision, .allow)
    }

    func test_allowsOfflinePlaceholder() {
        let url = URL(string: "http://offline/")!
        let decision = service.decide(for: url, isNewWindow: false)
        XCTAssertEqual(decision, .allow)
    }
}

// MARK: - NavigationDecision: Equatable

extension NavigationDecision: Equatable {
    public static func == (lhs: NavigationDecision, rhs: NavigationDecision) -> Bool {
        switch (lhs, rhs) {
        case (.allow, .allow), (.openExternal, .openExternal), (.cancel, .cancel):
            return true
        default:
            return false
        }
    }
}
