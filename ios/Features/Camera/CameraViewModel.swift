import AVFoundation
import SwiftUI
import Combine

enum CaptureStep: Int {
    case align = 0
    case checking
    case countdown
    case captured

    var instruction: String {
        switch self {
        case .align:     return "Position your face in the oval"
        case .checking:  return "Hold still..."
        case .countdown: return ""
        case .captured:  return "Great! Move to next angle"
        }
    }
}

@MainActor
final class CameraViewModel: NSObject, ObservableObject {
    @Published var previewLayer: AVCaptureVideoPreviewLayer?
    @Published var qualityHint: String = "Position your face in the oval"
    @Published var isQualityPass = false
    @Published var capturedPhotos: [UIImage] = []
    @Published var currentPhotoIndex = 1
    @Published var countdownValue: Int? = nil
    @Published var captureStep: CaptureStep = .align
    @Published var frameColor: Color = .white
    @Published var sessionError: String?

    let totalPhotos = 4
    let countdownSeconds = 3

    private let session = AVCaptureSession()
    private let output = AVCapturePhotoOutput()
    private let checker = QualityChecker()
    private let sessionQueue = DispatchQueue(label: "camera.session", qos: .userInteractive)

    private var passStartTime: Date?
    private var countdownTimer: Timer?
    private var checkTimer: Timer?
    private var captureCompletion: (([UIImage]) -> Void)?

    func start(completion: @escaping ([UIImage]) -> Void) {
        self.captureCompletion = completion
        sessionQueue.async { [weak self] in
            self?.configureSession()
            self?.session.startRunning()
        }
    }

    func stop() {
        sessionQueue.async { [weak self] in
            self?.session.stopRunning()
        }
        checkTimer?.invalidate()
        countdownTimer?.invalidate()
    }

    private func configureSession() {
        session.beginConfiguration()
        session.sessionPreset = .photo

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            DispatchQueue.main.async { self.sessionError = "Camera not available" }
            session.commitConfiguration()
            return
        }

        session.addInput(input)

        guard session.canAddOutput(output) else {
            session.commitConfiguration()
            return
        }
        session.addOutput(output)
        session.commitConfiguration()

        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill

        DispatchQueue.main.async {
            self.previewLayer = layer
            self.startQualityChecks()
        }
    }

    private func startQualityChecks() {
        checkTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.runQualityCheck()
        }
    }

    private func runQualityCheck() {
        guard captureStep == .align || captureStep == .checking else { return }
        guard let connection = session.connections.first,
              let sampleBuffer = createSampleBuffer() else { return }

        let result = checker.check(sampleBuffer: sampleBuffer)
        updateUI(for: result)
    }

    private func createSampleBuffer() -> CMSampleBuffer? {
        return nil
    }

    private func updateUI(for result: QualityResult) {
        switch result {
        case .pass:
            isQualityPass = true
            frameColor = .green
            qualityHint = "Hold still..."
            captureStep = .checking

            if passStartTime == nil {
                passStartTime = Date()
            } else if let start = passStartTime, Date().timeIntervalSince(start) >= 1.5 {
                startCountdown()
            }

        case .warning(let hint):
            isQualityPass = false
            frameColor = .yellow
            qualityHint = hint
            captureStep = .align
            passStartTime = nil

        case .failed(let reason):
            isQualityPass = false
            frameColor = .red
            qualityHint = reason
            captureStep = .align
            passStartTime = nil
        }
    }

    private func startCountdown() {
        guard captureStep != .countdown else { return }
        captureStep = .countdown
        checkTimer?.invalidate()
        countdownValue = countdownSeconds

        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        var remaining = countdownSeconds
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self else { timer.invalidate(); return }
            remaining -= 1
            UIImpactFeedbackGenerator(style: .light).impactOccurred()

            if remaining <= 0 {
                timer.invalidate()
                self.countdownValue = nil
                self.capturePhoto()
            } else {
                self.countdownValue = remaining
            }
        }
    }

    private func capturePhoto() {
        let settings = AVCapturePhotoSettings()
        output.capturePhoto(with: settings, delegate: self)
    }

    private func photoDidCapture(_ image: UIImage) {
        capturedPhotos.append(image)
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()

        if capturedPhotos.count >= totalPhotos {
            captureCompletion?(capturedPhotos)
        } else {
            currentPhotoIndex += 1
            captureStep = .captured
            passStartTime = nil
            frameColor = .white

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.captureStep = .align
                self.qualityHint = "Position your face in the oval"
                self.startQualityChecks()
            }
        }
    }
}

extension CameraViewModel: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else { return }

        let mirrored = UIImage(cgImage: image.cgImage!, scale: image.scale, orientation: .leftMirrored)
        Task { @MainActor in
            self.photoDidCapture(mirrored)
        }
    }
}
