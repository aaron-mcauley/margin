//
//  GeneratedStroke.swift
//  Margin
//
//  Created by Cerebro on 11/17/26.
//




import CoreGraphics
import Foundation

struct GeneratedStroke: Decodable {
    let id: String
    let points: [CGFloat]
    let width: CGFloat
    let color: String
    let characterIndex: Int?
    let character: String?

    var locations: [CGPoint] {
        stride(from: 0, to: points.count - 1, by: 2).map {
            CGPoint(x: points[$0], y: points[$0 + 1])
        }
    }
}

struct HandwritingResponse: Decodable {
    let strokes: [GeneratedStroke]
}

struct HandwritingPlacement: Encodable {
    let x: CGFloat
    let y: CGFloat
    let averageLineHeight: CGFloat
    let width: CGFloat
    let color: String
    let maxWidth: CGFloat
}

struct HandwritingRequest: Encodable {
    let text: String
    let placement: HandwritingPlacement
}
