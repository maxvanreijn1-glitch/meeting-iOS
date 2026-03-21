// LoggingService.swift
// meeting-iOS
//
// Centralized, level-based logging using Swift's unified logging system (os.Logger).

import Foundation
import OSLog

// MARK: - Protocol

protocol LoggingServiceProtocol {
    func debug(_ message: String, file: String, function: String, line: Int)
    func info(_ message: String, file: String, function: String, line: Int)
    func warning(_ message: String, file: String, function: String, line: Int)
    func error(_ message: String, file: String, function: String, line: Int)
}

// MARK: - Implementation

final class LoggingService: LoggingServiceProtocol {

    // MARK: - Singleton

    static let shared = LoggingService()

    // MARK: - Private

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "co.median.ios", category: "App")

    private init() {}

    // MARK: - Public API

    func debug(
        _ message: String,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        let tag = makeTag(file: file, function: function, line: line)
        logger.debug("\(tag, privacy: .public) \(message, privacy: .public)")
    }

    func info(
        _ message: String,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        let tag = makeTag(file: file, function: function, line: line)
        logger.info("\(tag, privacy: .public) \(message, privacy: .public)")
    }

    func warning(
        _ message: String,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        let tag = makeTag(file: file, function: function, line: line)
        logger.warning("\(tag, privacy: .public) \(message, privacy: .public)")
    }

    func error(
        _ message: String,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        let tag = makeTag(file: file, function: function, line: line)
        logger.error("\(tag, privacy: .public) \(message, privacy: .public)")
    }

    // MARK: - Helpers

    private func makeTag(file: String, function: String, line: Int) -> String {
        let filename = URL(fileURLWithPath: file).deletingPathExtension().lastPathComponent
        return "[\(filename):\(line)]"
    }
}
