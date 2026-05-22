import SwiftUI
import Photos

@MainActor
final class ResultsGalleryViewModel: ObservableObject {
    @Published var job: Job?
    @Published var isLoading = true
    @Published var error: Error?
    @Published var saveSuccess = false
    @Published var hoursLeft: Int = 24

    private var countdownTimer: Timer?
    let jobId: String

    init(jobId: String) {
        self.jobId = jobId
    }

    func load() {
        Task {
            do {
                job = try await HeadshotService.shared.fetchJob(jobId: jobId)
                isLoading = false
                startCountdown()
            } catch {
                self.error = error
                isLoading = false
            }
        }
    }

    private func startCountdown() {
        hoursLeft = job?.hoursUntilDeletion ?? 24
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            guard let self, self.hoursLeft > 0 else { return }
            self.hoursLeft -= 1
        }
    }

    func downloadImage(url: String) async {
        guard let imageURL = URL(string: url),
              let (data, _) = try? await URLSession.shared.data(from: imageURL),
              let image = UIImage(data: data) else { return }

        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else { return }

        await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.creationRequestForAsset(from: image)
        }
        saveSuccess = true
    }

    func shareImage(url: String) -> URL? {
        URL(string: url)
    }

    func setAsLinkedInPhoto(url: String) {
        let linkedInURL = URL(string: "linkedin://")!
        if UIApplication.shared.canOpenURL(linkedInURL) {
            UIApplication.shared.open(linkedInURL)
        } else {
            UIApplication.shared.open(URL(string: "https://www.linkedin.com/profile/")!)
        }
    }

    deinit {
        countdownTimer?.invalidate()
    }
}

struct ResultsGalleryView: View {
    let jobId: String

    @EnvironmentObject var coordinator: AppCoordinator
    @StateObject private var viewModel: ResultsGalleryViewModel
    @State private var selectedImageURL: String?
    @State private var showShareSheet = false
    @State private var shareURL: URL?
    @State private var longPressedURL: String?
    @State private var showActionSheet = false

    init(jobId: String) {
        self.jobId = jobId
        _viewModel = StateObject(wrappedValue: ResultsGalleryViewModel(jobId: jobId))
    }

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        NavigationView {
            Group {
                if viewModel.isLoading {
                    loadingView
                } else if let job = viewModel.job, let urls = job.resultUrls, !urls.isEmpty {
                    galleryView(urls: urls)
                } else {
                    emptyView
                }
            }
            .navigationTitle("Your Headshots")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { coordinator.goHome() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    regenerateButton
                }
            }
        }
        .onAppear { viewModel.load() }
        .sheet(isPresented: .constant(selectedImageURL != nil)) {
            if let url = selectedImageURL {
                FullScreenImageView(url: url) {
                    selectedImageURL = nil
                }
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let url = shareURL {
                ShareSheet(items: [url])
            }
        }
        .confirmationDialog("Photo Options", isPresented: $showActionSheet, titleVisibility: .visible) {
            if let url = longPressedURL {
                Button("Download to Photos") {
                    Task { await viewModel.downloadImage(url: url) }
                }
                Button("Share") {
                    shareURL = viewModel.shareImage(url: url)
                    showShareSheet = shareURL != nil
                }
                Button("Set as LinkedIn Photo") {
                    viewModel.setAsLinkedInPhoto(url: url)
                }
                Button("Cancel", role: .cancel) {}
            }
        }
        .alert("Saved!", isPresented: $viewModel.saveSuccess) {
            Button("OK") {}
        } message: {
            Text("Photo saved to your library.")
        }
    }

    private func galleryView(urls: [String]) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                privacyBanner
                    .padding()

                LazyVGrid(columns: columns, spacing: 4) {
                    ForEach(urls, id: \.self) { url in
                        AsyncImage(url: URL(string: url)) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill()
                            case .failure:
                                Color.gray.overlay(Image(systemName: "photo").foregroundColor(.white))
                            default:
                                Color.gray.opacity(0.3)
                                    .overlay(ProgressView())
                            }
                        }
                        .frame(minHeight: 180)
                        .clipped()
                        .onTapGesture { selectedImageURL = url }
                        .onLongPressGesture {
                            longPressedURL = url
                            showActionSheet = true
                        }
                    }
                }
            }
        }
    }

    private var privacyBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "lock.shield.fill")
                .foregroundColor(.orange)
            Text("Photos auto-deleted in \(viewModel.hoursLeft) hours")
                .font(.caption)
                .fontWeight(.medium)
            Spacer()
        }
        .padding(12)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(10)
    }

    private var regenerateButton: some View {
        Button {
            coordinator.startCapture()
        } label: {
            Label("Regenerate", systemImage: "arrow.clockwise")
                .font(.caption)
        }
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Loading your headshots...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }

    private var emptyView: some View {
        ContentUnavailableView(
            "No Photos Yet",
            systemImage: "photo.stack",
            description: Text("Your generated headshots will appear here.")
        )
    }
}

struct FullScreenImageView: View {
    let url: String
    let onDismiss: () -> Void

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            AsyncImage(url: URL(string: url)) { image in
                image
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(scale)
                    .gesture(
                        MagnificationGesture()
                            .onChanged { value in
                                scale = lastScale * value
                            }
                            .onEnded { _ in
                                lastScale = scale
                                if scale < 1 { withAnimation { scale = 1; lastScale = 1 } }
                                if scale > 5 { withAnimation { scale = 5; lastScale = 5 } }
                            }
                    )
            } placeholder: {
                ProgressView()
            }

            VStack {
                HStack {
                    Spacer()
                    Button(action: onDismiss) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundColor(.white.opacity(0.8))
                            .padding()
                    }
                }
                Spacer()
            }
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
