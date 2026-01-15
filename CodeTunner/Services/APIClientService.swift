//
//  APIClientService.swift
//  CodeTunner
//
//  Created by SPU AI CLUB
//  Copyright © 2024 AIPRENEUR. All rights reserved.
//

import Foundation
import Combine

enum HTTPMethod: String, CaseIterable, Identifiable {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
    case patch = "PATCH"
    case head = "HEAD"
    case options = "OPTIONS"
    
    var id: String { rawValue }
    
    var color: String {
        switch self {
        case .get: return "blue"
        case .post: return "green"
        case .put: return "orange"
        case .delete: return "red"
        default: return "gray"
        }
    }
}

struct APIRequest: Codable {
    var method: String
    var url: String
    var headers: [String: String]
    var body: String?
}

struct APIResponse: Codable {
    let status: Int
    let header_map: [String: String]
    let body: String
    let duration_ms: Int
}

class APIClientService: ObservableObject {
    static let shared = APIClientService()
    
    @Published var lastResponse: APIResponse?
    @Published var isLoading = false
    @Published var error: String?
    
    private let baseURL = "http://127.0.0.1:3000/api/network"
    
    func execute(_ request: APIRequest) async throws -> APIResponse {
        await MainActor.run {
            self.isLoading = true
            self.error = nil
            self.lastResponse = nil
        }
        
        defer {
            Task { await MainActor.run { self.isLoading = false } }
        }
        
        guard let url = URL(string: "\(baseURL)/proxy") else {
            throw NSError(domain: "APIClient", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid Proxy URL"])
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let encoder = JSONEncoder()
        urlRequest.httpBody = try encoder.encode(request)
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let errorMsg = String(data: data, encoding: .utf8) ?? "Unknown Error"
            await MainActor.run { self.error = errorMsg }
            throw NSError(domain: "APIClient", code: 500, userInfo: [NSLocalizedDescriptionKey: errorMsg])
        }
        
        let apiResponse = try JSONDecoder().decode(APIResponse.self, from: data)
        await MainActor.run { self.lastResponse = apiResponse }
        return apiResponse
    }
}
