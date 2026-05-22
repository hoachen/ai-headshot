import SwiftUI
import Combine

@MainActor
final class GenerationProgressViewModel: ObservableObject {
    @Published var displayProgress: Double = 0
    @Published var stateLabel: String = "Preparing..."
    @Published var estimatedSecondsLeft: Int = 30
    @Published var isFailed = false
    @Published var errorMessage: String?
    @Published var resultUrls: [String] = []
    @Published var isDone = false

    private var fakeProgressTimer: Timer?
    private var fakeProgress: Double = 0
    private var realProgress: Double = 0
    private var startTime = Date()
    private let jobId: String

    init(jobId: String) {
        self.jobId = jobId
    }

    func startStreaming(onComplete: @escaping (String) -> Void) {
        startFakeProgress()
        startTime = Date()

        HeadshotService.shared.streamProgress(
            jobId: jobId,
            onEvent: { [weak self] event in
                guard let self else { return }
                self.realProgress = event.pct / 100.0
                self.stateLabel = event.displayLabel
                self.mergeProgress()
            },
            onComplete: { [weak self] urls in
                guard let self else { return }
                self.stopFakeProgress()
                self.displayProgress = 1.0
                self.isDone = true
                onComplete(self.jobId)
            },
            onError: { [weak self] error in
                guard let self else { return }
                self.stopFakeProgress()
                self.isFailed = true
                self.errorMessage = error.localizedDescription
            }
        )
    }

    private func startFakeProgress() {
        fakeProgress = 0
        fakeProgressTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self else { return }
            if self.fakeProgress < 0.88 {
                let increment = (0.88 - self.fakeProgress) * 0.04
                self.fakeProgress += max(increment, 0.002)
            }
            self.mergeProgress()
            self.updateEstimate()
        }
    }

    private func stopFakeProgress() {
        fakeProgressTimer?.invalidate()
        fakeProgressTimer = nil
    }

    private func mergeProgress() {
        displayProgress = max(fakeProgress, realProgress)
    }

    private func updateEstimate() {
        let elapsed = Date().timeIntervalSince(startTime)
        let rate = displayProgress > 0 ? elapsed / displayProgress : 1
        let remaining = (1.0 - displayProgress) * rate
        estimatedSecondsLeft = max(1, Int(remaining))
    }

    func cancel() {
        stopFakeProgress()
        HeadshotService.shared.cancelStream()
    }
}

struct GenerationProgressView: View {
    let jobId: String

    @EnvironmentObject var coordinator: AppCoordinator
    @StateObject private var viewModel: GenerationProgressViewModel

    init(jobId: String) {
        self.jobId = jobId
        _viewModel = StateObject(wrappedValue: GenerationProgressViewModel(jobId: jobId))
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "0F0C29"), Color(hex: "302B63"), Color(hex: "24243E")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 40) {
                Spacer()

                animatedIcon

                VStack(spacing: 12) {
                    Text(viewModel.stateLabel)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .animation(.easeInOut, value: viewModel.stateLabel)

                    Text("~\(viewModel.estimatedSecondsLeft)s remaining")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.6))
                }

                progressBar

                Spacer()

                Button("Cancel") {
                    viewModel.cancel()
                    coordinator.goHome()
                }
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.5))
                .padding(.bottom, 40)
            }
            .padding(.horizontal, 32)
        }
        .onAppear {
            viewModel.startStreaming { jobId in
                coordinator.generationComplete(jobId: jobId)
            }
        }
        .alert("Generation Failed", isPresented: $viewModel.isFailed) {
            Button("Try Again") { coordinator.goHome() }
        } message: {
            Text(viewModel.errorMessage ?? "Something went wrong. Please try again.")
        }
    }

    private var animatedIcon: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    .frame(width: CGFloat(120 + index * 40), height: CGFloat(120 + index * 40))
                    .scaleEffect(viewModel.displayProgress > 0 ? 1.0 + Double(index) * 0.05 : 1.0)
                    .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true).delay(Double(index) * 0.2), value: viewModel.displayProgress)
            }

            Image(systemName: "person.fill.viewfinder")
                .font(.system(size: 48))
                .foregroundColor(.white)
                .symbolEffect(.pulse, isActive: !viewModel.isDone)
        }
    }

    private var progressBar: some View {
        VStack(spacing: 8) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.white.opacity(0.15))
                        .frame(height: 10)

                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "667eea"), Color(hex: "764ba2")],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * viewModel.displayProgress, height: 10)
                        .animation(.easeInOut(duration: 0.4), value: viewModel.displayProgress)
                }
            }
            .frame(height: 10)

            Text("\(Int(viewModel.displayProgress * 100))%")
                .font(.caption)
                .foregroundColor(.white.opacity(0.6))
        }
    }
}

extension Color {
    init(hex: String) {
        let scanner = Scanner(string: hex)
        var rgb: UInt64 = 0
        scanner.scanHexInt64(&rgb)
        let r = Double((rgb >> 16) & 0xFF) / 255
        let g = Double((rgb >> 8) & 0xFF) / 255
        let b = Double(rgb & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
