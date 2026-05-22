import SwiftUI
import RevenueCat

@MainActor
final class PaywallViewModel: ObservableObject {
    @Published var packages: [Package] = []
    @Published var selectedPackage: Package?
    @Published var isPurchasing = false
    @Published var isLoading = true
    @Published var purchaseError: String?
    @Published var isPro = false

    func load() {
        Task {
            do {
                let offerings = try await Purchases.shared.offerings()
                if let packages = offerings.current?.availablePackages {
                    self.packages = packages
                    self.selectedPackage = packages.first { $0.packageType == .monthly }
                }
            } catch {
                purchaseError = error.localizedDescription
            }
            isLoading = false
        }
    }

    func purchase(onSuccess: @escaping () -> Void) {
        guard let package = selectedPackage else { return }
        isPurchasing = true
        Task {
            do {
                let result = try await Purchases.shared.purchase(package: package)
                if result.customerInfo.entitlements[AppConfig.proEntitlement]?.isActive == true {
                    isPro = true
                    onSuccess()
                }
            } catch let err as ErrorCode where err == .purchaseCancelledError {
                // user cancelled — silent
            } catch {
                purchaseError = error.localizedDescription
            }
            isPurchasing = false
        }
    }

    func restorePurchases(onSuccess: @escaping () -> Void) {
        isPurchasing = true
        Task {
            do {
                let customerInfo = try await Purchases.shared.restorePurchases()
                if customerInfo.entitlements[AppConfig.proEntitlement]?.isActive == true {
                    isPro = true
                    onSuccess()
                } else {
                    purchaseError = "No active subscription found."
                }
            } catch {
                purchaseError = error.localizedDescription
            }
            isPurchasing = false
        }
    }

    var monthlyPackage: Package? {
        packages.first { $0.packageType == .monthly }
    }

    var annualPackage: Package? {
        packages.first { $0.packageType == .annual }
    }
}

struct PaywallView: View {
    @EnvironmentObject var coordinator: AppCoordinator
    @StateObject private var viewModel = PaywallViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "1a1a2e"), Color(hex: "16213e"), Color(hex: "0f3460")],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 28) {
                    headerSection
                    featureList
                    if viewModel.isLoading {
                        ProgressView().tint(.white)
                    } else {
                        packageSelector
                        ctaButton
                        legalText
                        restoreButton
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 32)
            }
        }
        .onAppear { viewModel.load() }
        .alert("Error", isPresented: .constant(viewModel.purchaseError != nil)) {
            Button("OK") { viewModel.purchaseError = nil }
        } message: {
            Text(viewModel.purchaseError ?? "")
        }
    }

    private var headerSection: some View {
        VStack(spacing: 12) {
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .foregroundColor(.white.opacity(0.6))
                    .padding(8)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)

            Image(systemName: "person.fill.checkmark")
                .font(.system(size: 56))
                .foregroundColor(.white)

            Text("Studio-Quality\nHeadshots")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)

            Text("Join 50,000+ professionals with\nAI-generated headshots")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
        }
    }

    private var featureList: some View {
        VStack(alignment: .leading, spacing: 14) {
            FeatureRow(icon: "wand.and.stars", text: "20 studio-quality headshots per generation")
            FeatureRow(icon: "4k.tv.fill",     text: "4K upscaling — print-ready resolution")
            FeatureRow(icon: "lock.shield",    text: "Photos auto-deleted in 24 hours")
            FeatureRow(icon: "arrow.clockwise", text: "Unlimited regenerations")
            FeatureRow(icon: "iphone",         text: "Native iOS — no browser upload needed")
        }
        .padding(20)
        .background(Color.white.opacity(0.08))
        .cornerRadius(16)
    }

    private var packageSelector: some View {
        VStack(spacing: 12) {
            if let monthly = viewModel.monthlyPackage {
                PackageCard(
                    title: "Monthly",
                    price: monthly.localizedPriceString,
                    badge: nil,
                    isSelected: viewModel.selectedPackage?.packageType == .monthly,
                    trialText: "7-day free trial"
                ) {
                    viewModel.selectedPackage = monthly
                }
            }

            if let annual = viewModel.annualPackage {
                PackageCard(
                    title: "Annual",
                    price: annual.localizedPriceString + "/yr",
                    badge: "Save 50%",
                    isSelected: viewModel.selectedPackage?.packageType == .annual,
                    trialText: "7-day free trial"
                ) {
                    viewModel.selectedPackage = annual
                }
            }
        }
    }

    private var ctaButton: some View {
        Button(action: {
            viewModel.purchase {
                dismiss()
            }
        }) {
            HStack {
                if viewModel.isPurchasing {
                    ProgressView().tint(.black)
                } else {
                    Text("Start 7-Day Free Trial")
                        .fontWeight(.bold)
                        .font(.headline)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(Color.white)
            .foregroundColor(.black)
            .cornerRadius(16)
        }
        .disabled(viewModel.isPurchasing || viewModel.selectedPackage == nil)
    }

    private var legalText: some View {
        Text("Free for 7 days, then auto-renews. Cancel anytime in Settings > Subscriptions.")
            .font(.caption2)
            .foregroundColor(.white.opacity(0.45))
            .multilineTextAlignment(.center)
    }

    private var restoreButton: some View {
        Button("Restore Purchases") {
            viewModel.restorePurchases { dismiss() }
        }
        .font(.caption)
        .foregroundColor(.white.opacity(0.5))
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundColor(.blue)
                .frame(width: 22)
            Text(text)
                .font(.subheadline)
                .foregroundColor(.white)
        }
    }
}

struct PackageCard: View {
    let title: String
    let price: String
    let badge: String?
    let isSelected: Bool
    let trialText: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(title)
                            .font(.headline)
                            .foregroundColor(.white)
                        if let badge {
                            Text(badge)
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.black)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.yellow)
                                .cornerRadius(8)
                        }
                    }
                    Text(trialText)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                }

                Spacer()

                Text(price)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            .padding(16)
            .background(isSelected ? Color.blue.opacity(0.3) : Color.white.opacity(0.08))
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? Color.blue : Color.white.opacity(0.2), lineWidth: 2)
            )
        }
    }
}
