// ConfigServiceTests.swift
// Tests/Unit
//
// Unit tests for ConfigService – JSON loading and property mapping.

import XCTest
@testable import Meetingsmanaged

final class ConfigServiceTests: XCTestCase {

    // MARK: - Tests

    func test_defaultURL_isNotEmpty() {
        let service = ConfigService.shared
        XCTAssertFalse(service.initialURL.absoluteString.isEmpty, "Initial URL must not be empty")
    }

    func test_appName_isNotEmpty() {
        let service = ConfigService.shared
        XCTAssertFalse(service.appName.isEmpty, "App name must not be empty")
    }

    func test_offlineTimeout_isPositive() {
        let service = ConfigService.shared
        XCTAssertGreaterThan(service.offlineTimeout, 0, "Offline timeout must be positive")
    }

    func test_configuration_generalInitialUrl_parses() {
        let service = ConfigService.shared
        let raw = service.configuration.general.initialUrl
        XCTAssertNotNil(URL(string: raw), "initialUrl in appConfig must be a valid URL string")
    }
}
