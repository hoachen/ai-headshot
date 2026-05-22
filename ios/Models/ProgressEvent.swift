import Foundation

struct ProgressEvent: Codable {
    let state: String
    let pct: Double
    let urls: [String]?
    let error: String?
    let errorCode: String?

    enum CodingKeys: String, CodingKey {
        case state, pct, urls, error
        case errorCode = "error_code"
    }

    var displayLabel: String {
        switch state {
        case "FACE_CHECK":   return "Analyzing face..."
        case "EMBEDDING":    return "Extracting features..."
        case "GENERATING":   return "Generating headshots..."
        case "UPSCALING":    return "Enhancing to 4K..."
        case "UPLOADING":    return "Finishing up..."
        case "DONE":         return "Complete!"
        case "FAILED":       return "Generation failed"
        default:             return "Processing..."
        }
    }
}
