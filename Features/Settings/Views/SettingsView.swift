// SettingsView.swift
// meeting-iOS
//
// In-app settings screen for debug/development use.

import SwiftUI

struct SettingsView: View {

    @StateObject private var viewModel = SettingsViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                // URL override
                Section {
                    TextField("Default: \(viewModel.defaultURL)", text: $viewModel.urlOverride)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                } header: {
                    Text("Custom Start URL")
                } footer: {
                    Text("Leave blank to use the configured default URL.")
                }

                // Version info
                Section("About") {
                    LabeledContent("Version", value: viewModel.appVersion)
                }

                // Actions
                Section {
                    Button("Reset to Default") {
                        viewModel.reset()
                    }
                    .foregroundStyle(.red)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        viewModel.save()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .overlay {
                if viewModel.isSaved {
                    Text("Saved ✓")
                        .font(.headline)
                        .padding(12)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.3), value: viewModel.isSaved)
        }
    }
}

// MARK: - Preview

#Preview {
    SettingsView()
}
