import SwiftUI
import AVFoundation

struct CameraView: View {
    @EnvironmentObject var coordinator: AppCoordinator
    @StateObject private var viewModel = CameraViewModel()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            CameraPreviewRepresentable(viewModel: viewModel)
                .ignoresSafeArea()

            FaceOvalOverlay(
                borderColor: viewModel.frameColor,
                isPass: viewModel.isQualityPass
            )

            VStack {
                topBar
                Spacer()
                bottomBar
            }
            .padding()

            if let countdown = viewModel.countdownValue {
                CountdownView(value: countdown)
            }

            if viewModel.captureStep == .captured {
                PhotoCapturedFlash()
            }
        }
        .onAppear {
            viewModel.start { photos in
                coordinator.captureComplete(photos: photos)
            }
        }
        .onDisappear {
            viewModel.stop()
        }
        .alert("Camera Error", isPresented: .constant(viewModel.sessionError != nil)) {
            Button("OK") { coordinator.goBack() }
        } message: {
            Text(viewModel.sessionError ?? "")
        }
    }

    private var topBar: some View {
        HStack {
            Button(action: { coordinator.goBack() }) {
                Image(systemName: "xmark")
                    .font(.title2)
                    .foregroundColor(.white)
                    .padding(12)
                    .background(Color.black.opacity(0.4))
                    .clipShape(Circle())
            }
            Spacer()
            Text("Photo \(viewModel.currentPhotoIndex) of \(viewModel.totalPhotos)")
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.black.opacity(0.5))
                .cornerRadius(20)
            Spacer()
            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.top, 8)
    }

    private var bottomBar: some View {
        VStack(spacing: 16) {
            ProgressDotsView(
                total: viewModel.totalPhotos,
                current: viewModel.currentPhotoIndex - 1
            )

            Text(viewModel.qualityHint)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
                .padding(.vertical, 10)
                .background(Color.black.opacity(0.55))
                .cornerRadius(12)
                .animation(.easeInOut, value: viewModel.qualityHint)
        }
        .padding(.bottom, 40)
    }
}

struct CameraPreviewRepresentable: UIViewRepresentable {
    let viewModel: CameraViewModel

    func makeUIView(context: Context) -> PreviewView {
        PreviewView()
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        if let layer = viewModel.previewLayer {
            uiView.setPreviewLayer(layer)
        }
    }
}

final class PreviewView: UIView {
    private var previewLayer: AVCaptureVideoPreviewLayer?

    func setPreviewLayer(_ layer: AVCaptureVideoPreviewLayer) {
        previewLayer?.removeFromSuperlayer()
        layer.frame = bounds
        self.layer.addSublayer(layer)
        previewLayer = layer
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer?.frame = bounds
    }
}

struct FaceOvalOverlay: View {
    let borderColor: Color
    let isPass: Bool

    var body: some View {
        GeometryReader { geometry in
            let ovalWidth = geometry.size.width * 0.7
            let ovalHeight = ovalWidth * 1.35
            let xOffset = (geometry.size.width - ovalWidth) / 2
            let yOffset = (geometry.size.height - ovalHeight) / 2 - 30

            ZStack {
                Rectangle()
                    .fill(Color.black.opacity(0.45))
                    .mask(
                        Rectangle()
                            .overlay(
                                Ellipse()
                                    .frame(width: ovalWidth, height: ovalHeight)
                                    .offset(x: 0, y: -30)
                                    .blendMode(.destinationOut)
                            )
                    )

                Ellipse()
                    .stroke(borderColor, lineWidth: 3)
                    .frame(width: ovalWidth, height: ovalHeight)
                    .offset(y: -30)
                    .animation(.easeInOut(duration: 0.3), value: borderColor)
            }
        }
    }
}

struct CountdownView: View {
    let value: Int

    var body: some View {
        Text("\(value)")
            .font(.system(size: 96, weight: .bold, design: .rounded))
            .foregroundColor(.white)
            .shadow(color: .black.opacity(0.5), radius: 10)
            .transition(.scale.combined(with: .opacity))
            .id(value)
    }
}

struct PhotoCapturedFlash: View {
    var body: some View {
        Color.white
            .ignoresSafeArea()
            .opacity(0.6)
            .transition(.opacity)
            .animation(.easeOut(duration: 0.3), value: true)
    }
}

struct ProgressDotsView: View {
    let total: Int
    let current: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<total, id: \.self) { index in
                Circle()
                    .fill(index <= current ? Color.white : Color.white.opacity(0.3))
                    .frame(width: 8, height: 8)
            }
        }
    }
}
