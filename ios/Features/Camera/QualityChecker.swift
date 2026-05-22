import Vision
import UIKit
import Accelerate

enum QualityResult {
    case pass
    case warning(hint: String)
    case failed(reason: String)
}

final class QualityChecker {
    private let faceRequest = VNDetectFaceLandmarksRequest()
    private let requestHandler: (CGImage) -> Void = { _ in }

    func check(sampleBuffer: CMSampleBuffer) -> QualityResult {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return .failed(reason: "Cannot read camera frame")
        }

        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            return .failed(reason: "Cannot process frame")
        }

        let brightnessResult = checkBrightness(pixelBuffer: pixelBuffer)
        if case .failed = brightnessResult { return brightnessResult }

        let sharpnessResult = checkSharpness(cgImage: cgImage)
        if case .failed = sharpnessResult { return sharpnessResult }

        let faceResult = checkFace(cgImage: cgImage)
        return faceResult
    }

    private func checkBrightness(pixelBuffer: CVPixelBuffer) -> QualityResult {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            return .warning(hint: "Cannot check brightness")
        }

        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let pixelFormat = CVPixelBufferGetPixelFormatType(pixelBuffer)

        guard pixelFormat == kCVPixelFormatType_32BGRA else {
            return .warning(hint: "Unexpected pixel format")
        }

        let buffer = baseAddress.assumingMemoryBound(to: UInt8.self)
        var totalLuminance: Double = 0
        let sampleStep = 4
        var sampleCount = 0

        for row in stride(from: 0, to: height, by: sampleStep) {
            for col in stride(from: 0, to: width, by: sampleStep) {
                let offset = row * bytesPerRow + col * 4
                let b = Double(buffer[offset])
                let g = Double(buffer[offset + 1])
                let r = Double(buffer[offset + 2])
                let luminance = 0.2126 * r + 0.7152 * g + 0.0722 * b
                totalLuminance += luminance
                sampleCount += 1
            }
        }

        let meanLuminance = sampleCount > 0 ? totalLuminance / Double(sampleCount) : 0
        if meanLuminance < 80 {
            return .failed(reason: "Move to a brighter spot")
        }
        return .pass
    }

    private func checkSharpness(cgImage: CGImage) -> QualityResult {
        let variance = laplacianVariance(cgImage: cgImage)
        if variance < 100 {
            return .failed(reason: "Hold still — slight blur detected")
        }
        return .pass
    }

    private func laplacianVariance(cgImage: CGImage) -> Double {
        let width = cgImage.width
        let height = cgImage.height
        guard width > 0, height > 0 else { return 0 }

        var rawData = [UInt8](repeating: 0, count: width * height)
        guard let context = CGContext(
            data: &rawData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return 0 }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        let kernel: [Float] = [0, 1, 0, 1, -4, 1, 0, 1, 0]
        var src = vImage_Buffer(
            data: &rawData,
            height: vImagePixelCount(height),
            width: vImagePixelCount(width),
            rowBytes: width
        )

        var laplacianData = [Float](repeating: 0, count: width * height)
        var dst = vImage_Buffer(
            data: &laplacianData,
            height: vImagePixelCount(height),
            width: vImagePixelCount(width),
            rowBytes: width * MemoryLayout<Float>.size
        )

        kernel.withUnsafeBufferPointer { kernelPtr in
            _ = vImageConvolve_Planar8ToPlanarF(
                &src, &dst, nil, 0, 0,
                kernelPtr.baseAddress!, 3, 3, 1.0, 0.0,
                vImage_Flags(kvImageEdgeExtend)
            )
        }

        let count = vDSP_Length(laplacianData.count)
        var mean: Float = 0
        var variance: Float = 0
        vDSP_normalize(laplacianData, 1, nil, 1, &mean, &variance, count)
        return Double(variance)
    }

    private func checkFace(cgImage: CGImage) -> QualityResult {
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        let request = VNDetectFaceLandmarksRequest()
        request.revision = VNDetectFaceLandmarksRequestRevision3

        do {
            try handler.perform([request])
        } catch {
            return .failed(reason: "Please face the camera directly")
        }

        guard let observations = request.results, !observations.isEmpty else {
            return .failed(reason: "Please face the camera directly")
        }

        guard let face = observations.first else {
            return .failed(reason: "Please face the camera directly")
        }

        if face.confidence < 0.7 {
            return .failed(reason: "Please face the camera directly")
        }

        let faceArea = face.boundingBox.width * face.boundingBox.height
        if faceArea < 0.20 {
            return .failed(reason: "Move a little closer")
        }

        if let yaw = face.yaw?.doubleValue, abs(yaw) > 0.44 {
            return .failed(reason: "Please face forward")
        }

        if let pitch = face.pitch?.doubleValue, abs(pitch) > 0.35 {
            return .failed(reason: "Please hold your head level")
        }

        if let landmarks = face.landmarks {
            let leftEyeConf = landmarks.leftEye != nil ? 1.0 : 0.0
            let rightEyeConf = landmarks.rightEye != nil ? 1.0 : 0.0
            if leftEyeConf < 0.5 || rightEyeConf < 0.5 {
                return .warning(hint: "Remove glasses or hat if possible")
            }
        }

        return .pass
    }
}
