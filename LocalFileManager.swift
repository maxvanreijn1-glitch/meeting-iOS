// LocalFileManager.swift
// Claude-powered local file integration — Swift utilities for iOS

import Foundation

// MARK: - Data Models

/// Metadata for a single file entry.
struct FileEntry {
    let url: URL
    var relativePath: String
    var size: Int64
    var fileExtension: String
    var lastModified: Date
    var language: String
}

/// Language distribution statistics.
struct LanguageStats {
    var fileCount: Int
    var totalBytes: Int64
    var percentage: Double
}

/// Represents a detected file-system change.
struct FileChange {
    enum ChangeType { case added, modified, deleted }
    var url: URL
    var changeType: ChangeType
    var timestamp: Date
    var previousSize: Int64?
    var currentSize: Int64?
}

// MARK: - LocalFileManager

/// Swift helper that indexes, monitors, reads, and writes local files.
/// Designed to work alongside the TypeScript CLI and Objective-C utilities.
class LocalFileManager {

    // MARK: Properties

    private let rootURL: URL
    private var fileIndex: [FileEntry] = []
    private var watchedStats: [URL: FileAttributes] = [:]
    private(set) var changeHistory: [FileChange] = []
    private var watchTimer: Timer?

    /// Map of file extensions → display language name.
    private static let languageMap: [String: String] = [
        ".m":          "Objective-C",
        ".h":          "Objective-C/C",
        ".swift":      "Swift",
        ".js":         "JavaScript",
        ".ts":         "TypeScript",
        ".sh":         "Shell",
        ".html":       "HTML",
        ".htm":        "HTML",
        ".rb":         "Ruby",
        ".json":       "JSON",
        ".md":         "Markdown",
        ".xml":        "XML",
        ".plist":      "XML/Plist",
        ".xib":        "Interface Builder",
        ".storyboard": "Interface Builder",
        ".css":        "CSS",
    ]

    private static let ignoredNames: Set<String> = [
        "node_modules", ".git", "Pods", "DerivedData",
        "xcuserdata", ".DS_Store", "dist", ".build",
    ]

    // MARK: Init

    init(rootPath: String) {
        rootURL = URL(fileURLWithPath: rootPath, isDirectory: true)
    }

    // MARK: Indexing

    /// Indexes all files under the root, populating `fileIndex`.
    @discardableResult
    func indexFiles() -> [FileEntry] {
        var entries: [FileEntry] = []
        traverse(directory: rootURL, into: &entries)
        fileIndex = entries
        return entries
    }

    private func traverse(directory: URL, into entries: inout [FileEntry]) {
        guard let items = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey],
            options: .skipsHiddenFiles
        ) else { return }

        for item in items {
            let name = item.lastPathComponent
            guard !Self.ignoredNames.contains(name) else { continue }

            let isDir = (try? item.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            if isDir {
                traverse(directory: item, into: &entries)
            } else {
                let attrs = FileAttributes(url: item)
                let ext = "." + item.pathExtension.lowercased()
                let language = Self.languageMap[ext] ?? "Other"
                let relative = item.path.replacingOccurrences(of: rootURL.path + "/", with: "")
                entries.append(FileEntry(
                    url: item,
                    relativePath: relative,
                    size: attrs?.size ?? 0,
                    fileExtension: ext,
                    lastModified: attrs?.modifiedDate ?? Date(),
                    language: language
                ))
            }
        }
    }

    // MARK: Statistics

    /// Computes per-language statistics from the current index.
    func computeStatistics() -> [String: LanguageStats] {
        let total = fileIndex.reduce(0) { $0 + $1.size }
        var map: [String: (count: Int, bytes: Int64)] = [:]

        for file in fileIndex {
            var entry = map[file.language] ?? (0, 0)
            entry.count += 1
            entry.bytes += file.size
            map[file.language] = entry
        }

        return map.mapValues { data in
            LanguageStats(
                fileCount: data.count,
                totalBytes: data.bytes,
                percentage: total > 0 ? Double(data.bytes) / Double(total) * 100 : 0
            )
        }
    }

    // MARK: File Operations

    /// Reads a file relative to the root and returns its contents as a String.
    func readFile(relativePath: String) throws -> String {
        let url = rootURL.appendingPathComponent(relativePath)
        return try String(contentsOf: url, encoding: .utf8)
    }

    /// Writes content to a file relative to the root, creating directories as needed.
    func writeFile(relativePath: String, content: String) throws {
        let url = rootURL.appendingPathComponent(relativePath)
        let dir = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try content.write(to: url, atomically: true, encoding: .utf8)
    }

    /// Lists files, optionally filtering by subdirectory and/or extension.
    func listFiles(inSubdirectory subdir: String? = nil,
                   withExtension ext: String? = nil) -> [FileEntry] {
        var result = fileIndex

        if let subdir {
            result = result.filter { $0.relativePath.hasPrefix(subdir) }
        }
        if let ext {
            let normalised = ext.hasPrefix(".") ? ext : ".\(ext)"
            result = result.filter { $0.fileExtension == normalised }
        }
        return result
    }

    // MARK: Change Watching

    /// Starts polling for file-system changes every `interval` seconds.
    func startWatching(interval: TimeInterval = 3.0) {
        guard watchTimer == nil else { return }

        // Seed snapshot
        for file in fileIndex {
            watchedStats[file.url] = FileAttributes(url: file.url)
        }

        watchTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.checkForChanges()
        }
        print("👁  Watching \(rootURL.path) every \(interval)s …")
    }

    /// Stops the file-system polling timer.
    func stopWatching() {
        watchTimer?.invalidate()
        watchTimer = nil
        print("⏹  Stopped watching.")
    }

    private func checkForChanges() {
        let now = Date()

        // Check existing
        for (url, oldAttrs) in watchedStats {
            if let newAttrs = FileAttributes(url: url) {
                if newAttrs.modifiedDate != oldAttrs.modifiedDate {
                    changeHistory.append(FileChange(
                        url: url, changeType: .modified, timestamp: now,
                        previousSize: oldAttrs.size, currentSize: newAttrs.size
                    ))
                    watchedStats[url] = newAttrs
                }
            } else {
                changeHistory.append(FileChange(
                    url: url, changeType: .deleted, timestamp: now,
                    previousSize: oldAttrs.size
                ))
                watchedStats.removeValue(forKey: url)
            }
        }

        // Detect new files
        var fresh: [FileEntry] = []
        traverse(directory: rootURL, into: &fresh)
        for file in fresh where watchedStats[file.url] == nil {
            if let attrs = FileAttributes(url: file.url) {
                watchedStats[file.url] = attrs
                changeHistory.append(FileChange(
                    url: file.url, changeType: .added, timestamp: now,
                    currentSize: attrs.size
                ))
            }
        }
    }

    // MARK: Reporting

    /// Prints a formatted project statistics report to stdout.
    func printStatistics() {
        let stats = computeStatistics()
        let totalFiles = fileIndex.count
        let totalBytes = fileIndex.reduce(0) { $0 + $1.size }

        print("\n📊 Project Statistics")
        print(String(repeating: "═", count: 50))
        print("  Total files : \(totalFiles)")
        print("  Total size  : \(String(format: "%.1f", Double(totalBytes) / 1024)) KB")
        print("\n  Language breakdown:")

        let sorted = stats.sorted { $0.value.percentage > $1.value.percentage }
        for (lang, data) in sorted {
            let bar = String(repeating: "█", count: Int(data.percentage / 2))
            print(String(format: "    %-20s %-25s %.1f%% (%d files)",
                         lang, bar, data.percentage, data.fileCount))
        }
        print(String(repeating: "═", count: 50))
    }
}

// MARK: - FileAttributes helper

private struct FileAttributes {
    let size: Int64
    let modifiedDate: Date

    init?(url: URL) {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attrs[.size] as? Int64,
              let date = attrs[.modificationDate] as? Date
        else { return nil }
        self.size = size
        self.modifiedDate = date
    }
}
