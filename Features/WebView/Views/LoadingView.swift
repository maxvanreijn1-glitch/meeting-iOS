// LoadingView.swift
// meeting-iOS
//
// A translucent progress bar and spinner shown while the WebView is loading.

import SwiftUI

struct LoadingView: View {
    let progress: Double

    var body: some View {
        VStack(spacing: 0) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.accentColor.opacity(0.2))
                        .frame(height: 3)

                    Rectangle()
                        .fill(Color.accentColor)
                        .frame(width: geo.size.width * progress, height: 3)
                        .animation(.linear(duration: 0.1), value: progress)
                }
            }
            .frame(height: 3)

            Spacer()
        }
    }
}

// MARK: - Preview

#Preview {
    LoadingView(progress: 0.6)
        .frame(height: 100)
}
