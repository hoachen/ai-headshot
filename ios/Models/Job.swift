import Foundation

enum JobStatus: String, Codable {
    case pending      = "PENDING"
    case faceCheck    = "FACE_CHECK"
    case embedding    = "EMBEDDING"
    case generating   = "GENERATING"
    case upscaling    = "UPSCALING"
    case uploading    = "UPLOADING"
    case done         = "DONE"
    case failed       = "FAILED"
}

struct Job: Codable, Identifiable {
    let id: String
    let userId: String
    let status: JobStatus
    let tier: String
    let industry: String
    let style: String
    let errorCode: String?
    let resultUrls: [String]?
    let photosDeletedAt: Date?
    let createdAt: Date
    let completedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, userId = "user_id", status, tier, industry, style
        case errorCode = "error_code"
        case resultUrls = "result_urls"
        case photosDeletedAt = "photos_deleted_at"
        case createdAt = "created_at"
        case completedAt = "completed_at"
    }

    var hoursUntilDeletion: Int? {
        guard let deletedAt = photosDeletedAt else { return nil }
        let seconds = deletedAt.timeIntervalSinceNow
        guard seconds > 0 else { return 0 }
        return Int(seconds / 3600)
    }
}

struct JobListResponse: Codable {
    let jobs: [Job]
}

struct SubmitJobResponse: Codable {
    let jobId: String

    enum CodingKeys: String, CodingKey {
        case jobId = "jobId"
    }
}
