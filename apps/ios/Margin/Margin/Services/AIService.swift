//
//  Untitled.swift
//  Margin
//
//  Created by Triz on 6/21/26.
//

import Foundation
import UIKit

struct AIService {
    private let apiKey = "REDACTED_OPENAI_API_KEY"
    
    func imageInquiry (_ image: UIImage) async throws -> String {
        guard let imageData = image.pngData() else {
            throw URLError(.cannotDecodeContentData)
        }
        
        let base64Image = imageData.base64EncodedString()
        let imageURL = "data:image/png;base64,\(base64Image)"
        
        let url = URL(string: "https://api.openai.com/v1/responses")!
        
        let body: [String: Any] = [
            "model": "gpt-4.1-mini",
            "input": [
                [
                    "role": "user",
                    "content": [
                        [
                            "type": "input_text",
                            "text": "Read the handwritten or typed question and return ONLY the answer. Do not repeat the question. Do not say 'The answer is'. Keep the response under 50 words."
                        ],
                        [
                            "type": "input_image",
                            "image_url": imageURL
                        ]
                    ]
                ]
            ]
        ]
    
        
        let jsonData = try JSONSerialization.data(withJSONObject: body)
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "content-Type")
        request.httpBody = jsonData
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse,
           !(200...299).contains(httpResponse.statusCode) {
            let errorText = String(data: data, encoding: .utf8) ?? "Unknown API error"
            throw NSError(domain: "OpenAI", code: httpResponse.statusCode, userInfo: [
                NSLocalizedDescriptionKey: errorText
            ])
        }
        
        let decoded = try JSONDecoder().decode(OpenAIResponse.self, from: data)
        
        return decoded.output
            .flatMap { $0.content }
            .compactMap { $0.text }
            .joined(separator: "\n")
    }
}

struct OpenAIResponse: Codable {
    let output: [OpenAIOutput]
}

struct OpenAIOutput: Codable {
    let content: [OpenAIContent]
}

struct OpenAIContent: Codable {
    let text: String?
}

