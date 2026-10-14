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
    private let lineGap: CGFloat = 36
    private let maxSearchDistance: CGFloat = 120


    // MARK: - Smart Crop

    func cropQuestion(
        above underline: PKStroke,
        in drawing: PKDrawing
    ) -> SmartCropResult? {

        let underlineBounds = underline.renderBounds


        // Find handwriting strokes that:
        // 1. Are above the underline
        // 2. Horizontally overlap the underline

        let candidates = drawing.strokes
            .filter { stroke in

                let bounds = stroke.renderBounds

                let horizontallyOverlaps =
                    bounds.maxX >= underlineBounds.minX &&
                    bounds.minX <= underlineBounds.maxX

                let distanceAboveUnderline = underlineBounds.minY - bounds.maxY
                
                let isWithinSearchRegion = distanceAboveUnderline >= 0 && distanceAboveUnderline <= maxSearchDistance
                
                return horizontallyOverlaps && isWithinSearchRegion
            }
            .map { stroke in

                let bounds = stroke.renderBounds

                return CandidateStroke(
                    stroke: stroke,
                    bounds: bounds,
                    distanceFromUnderline:
                        underlineBounds.minY - bounds.maxY
                )
            }
            .sorted {
                $0.distanceFromUnderline < $1.distanceFromUnderline
            }


        guard let nearest = candidates.first else {
            print("SMART CROP: No handwriting found above underline")
            return nil
        }


        // Find strokes that appear to belong to the
        // same handwritten line as the nearest stroke.

        let questionStrokes = candidates.filter { candidate in

            abs(
                candidate.bounds.maxY -
                nearest.bounds.maxY
            ) <= lineGap
        }


        guard !questionStrokes.isEmpty else {
            return nil
        }


        // Combine all question stroke bounds.

        var questionBounds = questionStrokes[0].bounds

        for candidate in questionStrokes.dropFirst() {
            questionBounds = questionBounds.union(candidate.bounds)
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
            questionStrokes.map { $0.stroke }
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

private struct CandidateStroke {

    let stroke: PKStroke
    let bounds: CGRect
    let distanceFromUnderline: CGFloat
}
