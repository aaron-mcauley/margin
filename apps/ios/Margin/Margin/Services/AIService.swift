//
//  Untitled.swift
//  Margin
//
//  Created by Triz on 6/21/26.
//

import Foundation

struct AIService {
    private let baseURL = "http://localhost:3001"
    
    func ask(_ question: String) async throws -> String {
        
        guard let url = URL(string: "\(baseURL)/api/ai/ask") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = AIRequest(prompt: question)
        request.httpBody = try JSONEncoder().encode(body)
        
        let(data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw NSError(
                domain: "MarginAPI",
                code: httpResponse.statusCode,
                userInfo: [
                    NSLocalizedDescriptionKey:
                        String(data: data, encoding: .utf8) ?? "Unknown server error"
                ]
            )
        }
        
        let result = try JSONDecoder().decode(AIResponse.self, from: data)
        
        return result.answer
    }
}
private struct AIRequest: Encodable {
    let prompt: String
}

private struct AIResponse: Decodable {
    let answer: String
}
