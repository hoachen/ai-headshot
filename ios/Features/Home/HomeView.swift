import SwiftUI
import RevenueCat

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var recentJobs: [Job] = []
    @Published var isPro = false
    @Published var isLoading = false

    func load() {
        Task {
            isLoading = true
            do {
                recentJobs = try await HeadshotService.shared.listJobs()
                let info = try await Purchases.shared.customerInfo()
                isPro = info.entitlements[AppConfig.proEntitlement]?.isActive == true
            } catch {
                // non-critical, show empty state
            }
            isLoading = false
        }
    }
}

struct HomeView: View {
    @EnvironmentObject var coordinator: AppCoordinator
    @StateObject private var viewModel = HomeViewModel()
    @State private var showPaywall = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    heroCard
                    if !viewModel.recentJobs.isEmpty {
                        recentSection
                    }
                }
                .padding()
            }
            .navigationTitle("AI Headshot")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        coordinator.showSettings()
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .foregroundColor(.primary)
                    }
                }
            }
            .onAppear { viewModel.load() }
            .refreshable { viewModel.load() }
            .sheet(isPresented: $showPaywall) { PaywallView() }
        }
        .sheet(isPresented: $coordinator.isPresentingSettings) { SettingsView() }
        .sheet(isPresented: $coordinator.isPresentingPaywall) { PaywallView() }
    }

    private var heroCard: some View {
        VStack(spacing: 20) {
            ZStack {
                LinearGradient(
                    colors: [Color(hex: "667eea"), Color(hex: "764ba2")],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
                .cornerRadius(20)

                VStack(spacing: 16) {
                    Image(systemName: "person.fill.viewfinder")
                        .font(.system(size: 52))
                        .foregroundColor(.white)

                    VStack(spacing: 6) {
                        Text("Studio Headshot")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        Text("20 AI-generated professional photos")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                    }

                    Button {
                        coordinator.startCapture()
                    } label: {
                        Label("Create New Headshot", systemImage: "camera.fill")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.white)
                            .foregroundColor(Color(hex: "764ba2"))
                            .cornerRadius(12)
                    }
                    .padding(.horizontal)
                }
                .padding(24)
            }
            .frame(maxWidth: .infinity)

            if !viewModel.isPro {
                tierBadge
            }
        }
    }

    private var tierBadge: some View {
        HStack {
            Image(systemName: "star.fill")
                .foregroundColor(.orange)
            Text("Free plan · 1 watermarked preview")
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Button("Upgrade") { showPaywall = true }
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.blue)
        }
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Generations")
                .font(.headline)
                .fontWeight(.bold)

            ForEach(viewModel.recentJobs.prefix(5)) { job in
                JobRow(job: job) {
                    if job.status == .done {
                        coordinator.navigate(to: .results(jobId: job.id))
                    }
                }
            }
        }
    }
}

struct JobRow: View {
    let job: Job
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(job.status == .done ? Color.blue.opacity(0.12) : Color.gray.opacity(0.1))
                        .frame(width: 50, height: 50)
                    Image(systemName: job.status == .done ? "photo.fill" : "hourglass")
                        .foregroundColor(job.status == .done ? .blue : .gray)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("\(job.industry) · \(job.style)")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Text(job.status == .done ? "20 photos ready" : job.status.rawValue.capitalized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if job.status == .done {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(12)
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}
