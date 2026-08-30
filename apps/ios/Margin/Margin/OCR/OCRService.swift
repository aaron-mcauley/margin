//
//  OCRService.swift
//  Margin
//
//  Created by Triz on 7/25/26.
//

import UIKit
protocol OCRService {
    func recognizeText(from image: UIImage) async throws -> String
}
