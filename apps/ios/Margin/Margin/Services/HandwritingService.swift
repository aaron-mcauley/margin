//
//  HandwritingService.swift
//  Margin
//
//  Created by Cerebro on 11/17/26.
//


import Foundation

struct HandwritingService {
    // Use the same Mac LAN address as AIService.swift.
    private let baseURL = "http://192.168.1.142:3001"

    func generate(
        text: String,
        placement: HandwritingPlacement
    ) async throws -> [GeneratedStroke] {
        let url = URL(
            string: "\(baseURL)/api/ai/handwriting"
        )!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(
            "application/json",
            forHTTPHeaderField: "Content-Type"
        )

        request.httpBody = try JSONEncoder().encode(
            HandwritingRequest(
                text: text,
                placement: placement
            )
        )

        let (data, response) = try await URLSession.shared.data(
            for: request
        )

        guard let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }

        return try JSONDecoder()
            .decode(HandwritingResponse.self, from: data)
            .strokes
    }
}

