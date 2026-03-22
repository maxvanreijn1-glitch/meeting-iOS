// PricingViewController.swift
// meeting-iOS
//
// SwiftUI pricing screen showing subscription tiers for Meetings Managed.
// Opens the pricing section of the website and provides a native tier overview.

import SwiftUI
import WebKit

// MARK: - Pricing Tier Model

struct PricingTier: Identifiable {
    let id: String
    let name: String
    let price: String
    let period: String
    let features: [String]
    let isHighlighted: Bool
    let ctaLabel: String
}

// MARK: - PricingView

struct PricingView: View {

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = PricingViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.showWebFallback {
                    PricingWebView(url: viewModel.pricingURL)
                        .ignoresSafeArea(edges: .bottom)
                } else {
                    ScrollView {
                        VStack(spacing: 20) {
                            headerSection
                            tiersSection
                            footerSection
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Pricing")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("View Online") { viewModel.showWebFallback.toggle() }
                }
            }
        }
    }

    // MARK: Subviews

    private var headerSection: some View {
        VStack(spacing: 8) {
            Text("Choose Your Plan")
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)
            Text("Streamline your meetings with Meetings Managed")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 8)
    }

    private var tiersSection: some View {
        ForEach(viewModel.tiers) { tier in
            PricingTierCard(tier: tier) {
                viewModel.selectTier(tier)
            }
        }
    }

    private var footerSection: some View {
        VStack(spacing: 6) {
            Text("All plans include a 14-day free trial. Cancel anytime.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("View full pricing details") {
                viewModel.showWebFallback = true
            }
            .font(.footnote)
        }
        .padding(.top, 8)
    }
}

// MARK: - PricingTierCard

private struct PricingTierCard: View {

    let tier: PricingTier
    let onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(tier.name)
                    .font(.headline)
                Spacer()
                if tier.isHighlighted {
                    Text("POPULAR")
                        .font(.caption2.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.blue, in: Capsule())
                        .foregroundStyle(.white)
                }
            }

            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text(tier.price)
                    .font(.title.bold())
                Text(tier.period)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                ForEach(tier.features, id: \.self) { feature in
                    Label(feature, systemImage: "checkmark.circle.fill")
                        .font(.subheadline)
                        .foregroundStyle(.primary, .green)
                }
            }

            Button(action: onTap) {
                Text(tier.ctaLabel)
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
            .tint(tier.isHighlighted ? .blue : .secondary)
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(.background)
                .shadow(color: .black.opacity(tier.isHighlighted ? 0.15 : 0.06),
                        radius: tier.isHighlighted ? 12 : 6, y: 2)
        }
        .overlay {
            if tier.isHighlighted {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(.blue, lineWidth: 2)
            }
        }
    }
}

// MARK: - PricingViewModel

@MainActor
final class PricingViewModel: ObservableObject {

    @Published var showWebFallback = false

    // Base URL sourced from appConfig, with a static fallback.
    private static var baseURL: URL {
        GoNativeAppConfig.shared().initialURL ?? URL(string: "https://www.meetings-managed.com")!
    }

    let tiers: [PricingTier] = [
        PricingTier(
            id: "starter",
            name: "Starter",
            price: "Free",
            period: "",
            features: [
                "Up to 5 meetings/month",
                "Basic agenda templates",
                "Email summaries",
            ],
            isHighlighted: false,
            ctaLabel: "Get Started Free"
        ),
        PricingTier(
            id: "pro",
            name: "Professional",
            price: "$12",
            period: "/user/month",
            features: [
                "Unlimited meetings",
                "Advanced agenda templates",
                "AI-powered meeting notes",
                "Calendar integrations",
                "Priority support",
            ],
            isHighlighted: true,
            ctaLabel: "Start Free Trial"
        ),
        PricingTier(
            id: "enterprise",
            name: "Enterprise",
            price: "Custom",
            period: "",
            features: [
                "Everything in Professional",
                "SSO & advanced security",
                "Custom integrations",
                "Dedicated account manager",
                "SLA guarantee",
            ],
            isHighlighted: false,
            ctaLabel: "Contact Sales"
        ),
    ]

    var pricingURL: URL {
        URL(string: "#pricing", relativeTo: Self.baseURL)?.absoluteURL ?? Self.baseURL
    }

    func selectTier(_ tier: PricingTier) {
        // Open the pricing page for plan selection/checkout.
        if UIApplication.shared.canOpenURL(pricingURL) {
            UIApplication.shared.open(pricingURL)
        }
    }
}

// MARK: - PricingWebView (UIViewRepresentable)

struct PricingWebView: UIViewRepresentable {

    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.allowsBackForwardNavigationGestures = true
        let request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 20)
        webView.load(request)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}
}

// MARK: - Preview

#Preview {
    PricingView()
}
