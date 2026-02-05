import Foundation

/// Client for interacting with the 35bird.io web API
@MainActor
final class WebAPIClient: ObservableObject {
    static let shared = WebAPIClient()

    private let baseURL = "https://api.35bird.io/v1"
    private var authToken: String?

    @Published var isAuthenticated = false
    @Published var lastError: Error?

    private init() {}

    // MARK: - Authentication

    /// Set the authentication token
    func setAuthToken(_ token: String) {
        authToken = token
        isAuthenticated = !token.isEmpty
    }

    /// Clear authentication
    func clearAuth() {
        authToken = nil
        isAuthenticated = false
    }

    // MARK: - HTTP Methods

    /// Perform a GET request
    func get<T: Decodable>(_ path: String, as type: T.Type) async throws -> T {
        let request = try buildRequest(path: path, method: "GET")
        return try await performRequest(request, as: type)
    }

    /// Perform a GET request with query parameters
    func get<T: Decodable>(_ path: String, query: [String: String], as type: T.Type) async throws -> T {
        guard var urlComponents = URLComponents(string: "\(baseURL)\(path)") else {
            throw WebAPIError.invalidURL
        }
        urlComponents.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }

        guard let url = urlComponents.url else {
            throw WebAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        addHeaders(to: &request)

        return try await performRequest(request, as: type)
    }

    /// Perform a POST request
    func post<T: Decodable, B: Encodable>(_ path: String, body: B, as type: T.Type) async throws -> T {
        var request = try buildRequest(path: path, method: "POST")
        request.httpBody = try JSONEncoder().encode(body)
        return try await performRequest(request, as: type)
    }

    /// Perform a POST request without response body
    func post<B: Encodable>(_ path: String, body: B) async throws {
        var request = try buildRequest(path: path, method: "POST")
        request.httpBody = try JSONEncoder().encode(body)
        let _ = try await performRequest(request, as: EmptyResponse.self)
    }

    /// Perform a PUT request
    func put<T: Decodable, B: Encodable>(_ path: String, body: B, as type: T.Type) async throws -> T {
        var request = try buildRequest(path: path, method: "PUT")
        request.httpBody = try JSONEncoder().encode(body)
        return try await performRequest(request, as: type)
    }

    /// Perform a DELETE request
    func delete(_ path: String) async throws {
        let request = try buildRequest(path: path, method: "DELETE")
        let _ = try await performRequest(request, as: EmptyResponse.self)
    }

    // MARK: - Request Building

    private func buildRequest(path: String, method: String) throws -> URLRequest {
        guard let url = URL(string: "\(baseURL)\(path)") else {
            throw WebAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        addHeaders(to: &request)

        return request
    }

    private func addHeaders(to request: inout URLRequest) {
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
    }

    private func performRequest<T: Decodable>(_ request: URLRequest, as type: T.Type) async throws -> T {
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw WebAPIError.invalidResponse
        }

        // Check for errors
        if httpResponse.statusCode >= 400 {
            if let errorResponse = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
                throw WebAPIError.apiError(errorResponse.error)
            }
            throw WebAPIError.httpError(httpResponse.statusCode)
        }

        // Decode response
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(type, from: data)
        } catch {
            throw WebAPIError.decodingError(error)
        }
    }
}

// MARK: - Error Types

enum WebAPIError: Error {
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case apiError(APIError)
    case decodingError(Error)
    case notAuthenticated
}

struct APIError: Codable {
    let code: String
    let message: String
    let details: [String: String]?
}

struct APIErrorResponse: Codable {
    let error: APIError
}

struct EmptyResponse: Codable {}

// MARK: - API Response Types

struct ProjectsResponse: Codable {
    let projects: [APIProject]
}

struct APIProject: Codable {
    let id: String
    let name: String
    let path: String
    let lastCommit: Date?
    let totalCommits: Int
    let totalLines: Int
}

struct PromptsResponse: Codable {
    let prompts: [APIPrompt]
}

struct APIPrompt: Codable {
    let id: String
    let text: String
    let projectPath: String?
    let createdAt: Date
    let wasExecuted: Bool
}

struct SessionsResponse: Codable {
    let sessions: [APISession]
}

struct APISession: Codable {
    let id: String
    let providerType: String
    let model: String
    let startTime: Date
    let endTime: Date?
    let inputTokens: Int
    let outputTokens: Int
    let costUSD: Double
}

// MARK: - Web API Sync Types

struct APISyncPushRequest: Codable {
    let records: [APISyncRecord]
    let deletions: [APISyncDeletion]
}

struct APISyncRecord: Codable {
    let type: String
    let id: String
    let data: [String: String]
    let modifiedAt: Date
}

struct APISyncDeletion: Codable {
    let type: String
    let id: String
}

struct APISyncPushResponse: Codable {
    let accepted: [String]
    let conflicts: [APISyncConflict]
    let serverChangeToken: String
}

struct APISyncConflict: Codable {
    let id: String
    let serverModifiedAt: Date
    let serverData: [String: String]
}

struct APISyncPullResponse: Codable {
    let changes: [APISyncChange]
    let deletions: [APISyncDeletion]
    let serverChangeToken: String
}

struct APISyncChange: Codable {
    let type: String
    let id: String
    let action: String
    let data: [String: String]
}
