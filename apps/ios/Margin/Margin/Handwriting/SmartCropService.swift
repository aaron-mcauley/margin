//
//  SmartCropService.swift
//  Margin
//
//  Created by Triz on 7/27/26.
//

import PencilKit
import UIKit


struct SmartCropResult {
    let image: UIImage
    let bounds: CGRect
    let averageLineHeight: CGFloat
}


final class SmartCropService {
    // MARK: - Configuration

    private let paddingX: CGFloat = 16
    private let paddingY: CGFloat = 8
    private let maxSearchDistance: CGFloat = 120
    


    // MARK: - Smart Crop

    func cropQuestion(
        above underline: ConfirmedUnderline,
        in drawing: PKDrawing
    ) -> SmartCropResult? {

        let underlineStroke = underline.stroke
        let underlineBounds = underlineStroke.renderBounds
        print("""
        [SMARTCROP] ANALYSIS START
        underlineIndex: \(underline.strokeIndex)
        underlineBounds: \(underlineBounds)
        totalDrawingStrokes: \(drawing.strokes.count)
        """)

        // Find handwriting strokes that:
        // 1. Are above the underline
        // 2. Horizontally overlap the underline

        let handwritingStrokes = drawing.strokes.enumerated().compactMap {
            index, stroke -> PKStroke? in
            
            if index == underline.strokeIndex {
                print("[SMARTCROP] stroke \(index) REJECTED — CONFIRMED UNDERLINE")
                return nil
            }
            
            let bounds = stroke.renderBounds
            
            let horizontallyOverlaps =
                bounds.maxX >= underlineBounds.minX &&
                bounds.minX <= underlineBounds.maxX
            
            guard horizontallyOverlaps else {
                return nil
            }
            
            let verticalDistance =
                underlineBounds.midY - bounds.midY
            
            guard verticalDistance > 0 else {
                print(
                    "[SMARTCROP] stroke \(index) REJECTED — NOT ABOVE | distance=\(verticalDistance)"
                )
                return nil
            }
            
            guard verticalDistance <= maxSearchDistance else {
                print(
                    "[SMARTCROP] stroke \(index) REJECTED — TOO FAR | distance=\(verticalDistance)"
                )
                return nil
            }
            
            print(
                "[SMARTCROP] stroke \(index) CANDIDATE | distance=\(verticalDistance) | bounds=\(bounds)"
            )
            
            return stroke
        }
            
        print(
            "[SMARTCROP] CANDIDATE COUNT: \(handwritingStrokes.count)"
        )
        
        guard !handwritingStrokes.isEmpty else {
            print("SMART CROP: No handwriting candidates")
            return nil

        }
        
        let handwritingLines = groupIntoLines(
            handwritingStrokes
        )
        
        print(
            "[SMARTCROP] LINE COUNT: \(handwritingLines.count)"
        )

        for (index, line) in handwritingLines.enumerated() {
            
            let bounds = combinedBounds(of: line)
            
            print("""
            [SMARTCROP] LINE \(index)
            strokeCount: \(line.count)
            bounds: \(bounds)
            """)
        }
        
        let associatedLines = handwritingLines.compactMap { strokes -> HandwritingLine? in
            
            let bounds = combinedBounds(of: strokes)
            
            let verticalDistance = underlineBounds.midY - bounds.midY
            
            guard verticalDistance > 0, verticalDistance <= maxSearchDistance else {
                return nil
            }
            
            return HandwritingLine( strokes: strokes, bounds: bounds, distanceFromUnderline: verticalDistance)
        }
        
        guard let selectedLine = associatedLines.min(
            by: {
                $0.distanceFromUnderline < $1.distanceFromUnderline
            }
        ) else {
            print("SMART CROP: No associated handwriting line")
            return nil
        }
        
        let questionStrokes = selectedLine.strokes
    
        print("""
        [SMARTCROP] LINE SELECTED
        strokeCount: \(selectedLine.strokes.count)
        bounds: \(selectedLine.bounds)
        distanceFromUnderline: \(selectedLine.distanceFromUnderline)
        """)

        // Combine all question stroke bounds.

        var questionBounds = questionStrokes[0].renderBounds

        for stroke in questionStrokes.dropFirst() {
            questionBounds = questionBounds.union(stroke.renderBounds)
        }


        // Add padding around the handwriting.

        let cropBounds = CGRect(
            x: questionBounds.minX - paddingX,
            y: questionBounds.minY - paddingY,
            width: questionBounds.width + (paddingX * 2),
            height: questionBounds.height + (paddingY * 2)
        )


        // Calculate average handwriting height.

        let averageLineHeight = getAverageLineHeight(
            questionStrokes
        )


        // Render only the selected region of the PencilKit drawing.

        let drawingImage = drawing.image(
            from: cropBounds,
            scale: 2.0
        )
        
        let renderer = UIGraphicsImageRenderer(
            size: drawingImage.size
        )
        
        let image = renderer.image {
            context in
            
            UIColor.white.setFill()
            
            context.fill(
                CGRect(
                    origin: .zero,
                    size: drawingImage.size
                )
            )
            
            drawingImage.draw(
                in: CGRect(
                    origin: .zero,
                    size: drawingImage.size
                )
            )
        }
        
        return SmartCropResult(
            image: image,
            bounds: cropBounds,
            averageLineHeight: averageLineHeight
        )
    }

        
    private func groupIntoLines (
        _ strokes: [PKStroke]
    ) -> [[PKStroke]] {
        let sortedStrokes = strokes.sorted {
            $0.renderBounds.midY < $1.renderBounds.midY
        }
        
        var lines: [[PKStroke]] = []
        
        for stroke in sortedStrokes {
            let strokeBounds = stroke.renderBounds
            
            if let lineIndex =  lines.firstIndex(where: { line in
            
                let lineBounds = combinedBounds(of: line)
                
                let verticalOverlap = min(lineBounds.maxY, strokeBounds.maxY) - max(lineBounds.minY, strokeBounds.minY)
                
                if verticalOverlap >= 0 {
                    return true
                }
                
                let verticalGap = max( strokeBounds.minY - lineBounds.maxY, lineBounds.minY - strokeBounds.maxY )
                
                let referenceHeight = max( lineBounds.height, strokeBounds.height )
                
                return verticalGap <= referenceHeight * 0.5
            }) {
                lines[lineIndex].append(stroke)
            } else {
                lines.append([stroke])
            }
        }
            return lines
    }
        
        private func combinedBounds( of strokes: [PKStroke]) -> CGRect {
            guard let firstStroke = strokes.first else {
                return .null
            }
            
            return strokes.dropFirst().reduce(firstStroke.renderBounds) { bounds, stroke in
                bounds.union(stroke.renderBounds)
            }
        }

    // MARK: - Average Line Height

    private func getAverageLineHeight(
        _ strokes: [PKStroke]
    ) -> CGFloat {

        var heights = strokes
            .map { $0.renderBounds.height }
            .filter { $0 > 4 }
            .sorted()


        guard !heights.isEmpty else {
            return 24
        }


        // Remove extreme values if we have enough samples.

        if heights.count > 4 {
            heights.removeFirst()
            heights.removeLast()
        }


        let total = heights.reduce(0, +)

        return total / CGFloat(heights.count)
    }
}


// MARK: - Internal Model

private struct HandwritingLine {

    let strokes: [PKStroke]
    let bounds: CGRect
    let distanceFromUnderline: CGFloat
}
