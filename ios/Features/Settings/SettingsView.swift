import SwiftUI
import RevenueCat

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var customerInfo: CustomerInfo?
    @Published var isLoading = false
    @Published var showDeleteConfirm = false
    @Published var showDeleteSuccess = false
    @Published var error: String?

    var isPro: Bool {
        customerInfo?.entitlements[AppConfig.proEntitlement]?.isActive == true
    }

    var subscriptionStatus: String {
        guard isPro else { return "Free Plan" }
        if let expiry = customerInfo?.entitlements[AppConfig.proEntitlement]?.expirationDate {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            return "Pro • Renews \(formatter.string(from: expiry))"
        }
        return "Pro"
    }

    func load() {
        Task {
            do {
                customerInfo = try await Purchases.shared.customerInfo()
            } catch {
                self.error = error.localizedDescription
            }
        }
    }

    func manageSubscription() {
        if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
            UIApplication.shared.open(url)
        }
    }

    func deleteAccount() {
        isLoading = true
        Task {
            do {
                let _: EmptyResponse = try await APIClient.shared.request("/users/me", method: "DELETE")
                await TokenStore.shared.clear()
                showDeleteSuccess = true
            } catch {
                self.error = error.localizedDescription
            }
            isLoading = false
        }
    }
}

struct EmptyResponse: Codable {}

struct SettingsView: View {
    @EnvironmentObject var coordinator: AppCoordinator
    @StateObject private var viewModel = SettingsViewModel()
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("hasSeenOnboarding")    private var hasSeenOnboarding = true

    var body: some View {
        NavigationView {
            List {
                accountSection
                subscriptionSection
                notificationsSection
                privacySection
                aboutSection
            }
            .navigationTitle("Settings")
            .onAppear { viewModel.load() }
            .alert("Delete Account", isPresented: $viewModel.showDeleteConfirm) {
                Button("Delete Everything", role: .destructive) {
                    viewModel.deleteAccount()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete all your data and generated photos. This cannot be undone.")
            }
            .alert("Account Deleted", isPresented: $viewModel.showDeleteSuccess) {
                Button("OK") {
                    hasSeenOnboarding = false
                    coordinator.goHome()
                }
            } message: {
                Text("Your account and all data have been deleted.")
            }
            .alert("Error", isPresented: .constant(viewModel.error != nil)) {
                Button("OK") { viewModel.error = nil }
            } message: {
                Text(viewModel.error ?? "")
            }
        }
    }

    private var accountSection: some View {
        Section("Account") {
            HStack {
                Image(systemName: "person.circle.fill")
                    .font(.largeTitle)
                    .foregroundColor(.blue)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Signed in with Apple")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text(viewModel.subscriptionStatus)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var subscriptionSection: some View {
        Section("Subscription") {
            if viewModel.isPro {
                Label(viewModel.subscriptionStatus, systemImage: "star.fill")
                    .foregroundColor(.orange)
                Button("Manage Subscription") {
                    viewModel.manageSubscription()
                }
            } else {
                Button {
                    coordinator.showPaywall()
                } label: {
                    Label("Upgrade to Pro", systemImage: "arrow.up.circle.fill")
                        .foregroundColor(.blue)
                }
            }
        }
    }

    private var notificationsSection: some View {
        Section("Notifications") {
            Toggle("Generation Complete", isOn: $notificationsEnabled)
            Toggle("New Style Templates", isOn: $notificationsEnabled)
        }
    }

    private var privacySection: some View {
        Section("Privacy & Data") {
            NavigationLink("Privacy Policy") {
                WebView(url: URL(string: "https://aiheadshot.app/privacy")!)
            }
            NavigationLink("Terms of Service") {
                WebView(url: URL(string: "https://aiheadshot.app/terms")!)
            }
            Button(role: .destructive) {
                viewModel.showDeleteConfirm = true
            } label: {
                Label("Delete My Data", systemImage: "trash.fill")
            }
        }
    }

    private var aboutSection: some View {
        Section("About") {
            HStack {
                Text("Version")
                Spacer()
                Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                    .foregroundColor(.secondary)
            }
            Button("Rate the App") {
                if let url = URL(string: "https://apps.apple.com/app/id000000000?action=write-review") {
                    UIApplication.shared.open(url)
                }
            }
            Button("Contact Support") {
                if let url = URL(string: "mailto:support@aiheadshot.app") {
                    UIApplication.shared.open(url)
                }
            }
        }
    }
}

import WebKit

struct WebView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let view = WKWebView()
        view.load(URLRequest(url: url))
        return view
    }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
