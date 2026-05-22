import UIKit
import Combine

enum HeadshotError: LocalizedError {
    case noFaceDetected
    case lowQuality(String)
    case generationFailed(String)
    case uploadFailed

    var errorDescription: String? {
        switch self {
        case .noFaceDetected:         return "No face detected in photos. Please retake."
        case .lowQuality(let reason): return reason
        case .generationFailed(let m): return m
        case .uploadFailed:           return "Upload failed. Please check your connection."
        }
    }
}

@MainActor
final class HeadshotService: ObservableObject {
    static let shared = HeadshotService()

    @Published var progress: Double = 0
    @Published var stateLabel: String = ""
    @Published var isStreaming = false
    @Published var streamError: Error?

    private var streamTask: Task<Void, Never>?

    func submit(photos: [UIImage], industry: String, style: String, tier: String) async throws -> String {
        let jpegData = photos.compactMap { $0.jpegData(compressionQuality: 0.85) }
        guard jpegData.count == photos.count else { throw HeadshotError.uploadFailed }

        let fields = ["industry": industry, "style": style, "tier": tier]
        let responseData = try await APIClient.shared.multipartUpload(
            endpoint: "/jobs",
            images: jpegData,
            fields: fields
        )

        let decoder = JSONDecoder()
        let response = try decoder.decode(SubmitJobResponse.self, from: responseData)
        return response.jobId
    }

    func streamProgress(jobId: String, onEvent: @escaping (ProgressEvent) -> Void, onComplete: @escaping ([String]) -> Void, onError: @escaping (Error) -> Void) {
        streamTask?.cancel()
        isStreaming = true
        progress = 0
        stateLabel = "Starting..."

        streamTask = Task {
            do {
                let bytes = try APIClient.shared.streamBytes(endpoint: "/jobs/\(jobId)/stream")
                var buffer = ""

                for try await byte in bytes {
                    guard !Task.isCancelled else { break }
                    buffer += String(bytes: [byte], encoding: .utf8) ?? ""

                    while let range = buffer.range(of: "\n\n") {
                        let chunk = String(buffer[buffer.startIndex..<range.lowerBound])
                        buffer = String(buffer[range.upperBound...])

                        for line in chunk.components(separatedBy: "\n") {
                            if line.hasPrefix("data: ") {
                                let jsonString = String(line.dropFirst(6))
                                guard let data = jsonString.data(using: .utf8),
                                      let event = try? JSONDecoder().decode(ProgressEvent.self, from: data) else { continue }

                                await MainActor.run {
                                    self.progress = event.pct / 100.0
                                    self.stateLabel = event.displayLabel
                                    onEvent(event)
                                }

                                if event.state == "DONE", let urls = event.urls {
                                    await MainActor.run {
                                        self.isStreaming = false
                                        onComplete(urls)
                                    }
                                    return
                                }

                                if event.state == "FAILED" {
                                    let errMsg = event.error ?? "Generation failed"
                                    await MainActor.run {
                                        self.isStreaming = false
                                        onError(HeadshotError.generationFailed(errMsg))
                                    }
                                    return
                                }
                            }
                        }
                    }
                }
            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self.isStreaming = false
                    self.streamError = error
                    onError(error)
                }
            }
        }
    }

    func cancelStream() {
        streamTask?.cancel()
        streamTask = nil
        isStreaming = false
    }

    func fetchJob(jobId: String) async throws -> Job {
        return try await APIClient.shared.request("/jobs/\(jobId)")
    }

    func listJobs() async throws -> [Job] {
        let response: JobListResponse = try await APIClient.shared.request("/jobs")
        return response.jobs
    }
}
