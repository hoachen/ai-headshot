import Foundation

enum APIError: LocalizedError {
    case invalidURL
    case unauthorized
    case notFound
    case serverError(Int, String?)
    case decodingError(Error)
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:              return "Invalid URL"
        case .unauthorized:            return "Session expired. Please sign in again."
        case .notFound:                return "Resource not found"
        case .serverError(let c, let m): return m ?? "Server error (\(c))"
        case .decodingError(let e):    return "Failed to parse response: \(e.localizedDescription)"
        case .networkError(let e):     return e.localizedDescription
        }
    }
}

actor TokenStore {
    static let shared = TokenStore()
    private var jwt: String?

    func set(_ token: String) { jwt = token }
    func get() -> String?     { jwt }
    func clear()              { jwt = nil }
}

final class APIClient {
    static let shared = APIClient()

    private let session: URLSession
    private let decoder: JSONDecoder

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        self.session = URLSession(configuration: config)
        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601
    }

    func request<T: Decodable>(_ endpoint: String, method: String = "GET", body: Data? = nil) async throws -> T {
        return try await withRetry(maxAttempts: 3) {
            try await self.performRequest(endpoint, method: method, body: body)
        }
    }

    func requestRaw(_ endpoint: String, method: String = "GET", body: Data? = nil) async throws -> (Data, HTTPURLResponse) {
        return try await withRetry(maxAttempts: 3) {
            try await self.performRawRequest(endpoint, method: method, body: body)
        }
    }

    private func performRequest<T: Decodable>(_ endpoint: String, method: String, body: Data?) async throws -> T {
        let (data, _) = try await performRawRequest(endpoint, method: method, body: body)
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }

    private func performRawRequest(_ endpoint: String, method: String, body: Data?) async throws -> (Data, HTTPURLResponse) {
        guard let url = URL(string: AppConfig.baseURL + endpoint) else {
            throw APIError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let token = await TokenStore.shared.get() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = body

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.networkError(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw APIError.networkError(URLError(.badServerResponse))
        }

        switch http.statusCode {
        case 200...299:
            return (data, http)
        case 401:
            await TokenStore.shared.clear()
            throw APIError.unauthorized
        case 404:
            throw APIError.notFound
        default:
            let message = String(data: data, encoding: .utf8)
            throw APIError.serverError(http.statusCode, message)
        }
    }

    func multipartUpload(endpoint: String, images: [Data], fields: [String: String]) async throws -> Data {
        guard let url = URL(string: AppConfig.baseURL + endpoint) else {
            throw APIError.invalidURL
        }
        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        if let token = await TokenStore.shared.get() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        var body = Data()
        for (key, value) in fields {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }
        for (index, imageData) in images.enumerated() {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"photos\"; filename=\"photo\(index).jpg\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
            body.append(imageData)
            body.append("\r\n".data(using: .utf8)!)
        }
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw APIError.serverError((response as? HTTPURLResponse)?.statusCode ?? 0, nil)
        }
        return data
    }

    func streamBytes(endpoint: String) throws -> URLSession.AsyncBytes {
        guard let url = URL(string: AppConfig.baseURL + endpoint) else {
            throw APIError.invalidURL
        }
        var request = URLRequest(url: url)
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        return session.bytes(for: request).0
    }
}

private func withRetry<T>(maxAttempts: Int, delay: Double = 1.0, block: () async throws -> T) async throws -> T {
    var lastError: Error?
    for attempt in 0..<maxAttempts {
        do {
            return try await block()
        } catch APIError.unauthorized, APIError.notFound {
            throw lastError ?? APIError.networkError(URLError(.unknown))
        } catch {
            lastError = error
            if attempt < maxAttempts - 1 {
                let wait = delay * pow(2.0, Double(attempt))
                try await Task.sleep(nanoseconds: UInt64(wait * 1_000_000_000))
            }
        }
    }
    throw lastError ?? APIError.networkError(URLError(.unknown))
}
