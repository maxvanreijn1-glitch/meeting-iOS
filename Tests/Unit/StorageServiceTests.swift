// StorageServiceTests.swift
// Tests/Unit
//
// Unit tests for StorageService.

import XCTest
@testable import Meetingsmanaged

final class StorageServiceTests: XCTestCase {

    private let defaults = UserDefaults(suiteName: "TestSuite")!

    override func tearDown() {
        super.tearDown()
        defaults.removePersistentDomain(forName: "TestSuite")
    }

    // MARK: - Tests

    func test_apnsToken_roundtrip() {
        let service = StorageService.shared
        let token = "abcdef1234567890"
        service.apnsToken = token
        XCTAssertEqual(service.apnsToken, token)
        service.apnsToken = nil
        XCTAssertNil(service.apnsToken)
    }

    func test_effectiveInitialURL_fallsBackToConfig() {
        let service = StorageService.shared
        service.initialUrlOverride = nil
        XCTAssertEqual(service.effectiveInitialURL, ConfigService.shared.initialURL)
    }

    func test_effectiveInitialURL_usesOverride() {
        let service = StorageService.shared
        let override = "https://example.com"
        service.initialUrlOverride = override
        XCTAssertEqual(service.effectiveInitialURL.absoluteString, override)
        // Cleanup
        service.initialUrlOverride = nil
    }
}
