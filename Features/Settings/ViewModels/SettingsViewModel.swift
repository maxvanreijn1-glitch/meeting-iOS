// SettingsViewModel.swift
// meeting-iOS
//
// ViewModel for the Settings screen.

import Foundation
import Combine

@MainActor
final class SettingsViewModel: ObservableObject {

    // MARK: - Published

    @Published var urlOverride: String = ""
    @Published var isSaved: Bool = false

    // MARK: - Dependencies

    private let storageService: StorageService
    private let configService: ConfigService

    // MARK: - Init

    init(
        storageService: StorageService = .shared,
        configService: ConfigService = .shared
    ) {
        self.storageService = storageService
        self.configService = configService
        urlOverride = storageService.initialUrlOverride ?? ""
    }

    // MARK: - Computed

    var defaultURL: String {
        configService.initialURL.absoluteString
    }

    var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "–"
        let build   = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "–"
        return "\(version) (\(build))"
    }

    // MARK: - Actions

    func save() {
        let trimmed = urlOverride.trimmingCharacters(in: .whitespacesAndNewlines)
        storageService.initialUrlOverride = trimmed.isEmpty ? nil : trimmed
        isSaved = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.isSaved = false
        }
        LoggingService.shared.info("Settings saved – URL override: \(trimmed.isEmpty ? "(none)" : trimmed)")
    }

    func reset() {
        urlOverride = ""
        storageService.initialUrlOverride = nil
        LoggingService.shared.info("Settings reset.")
    }
}
