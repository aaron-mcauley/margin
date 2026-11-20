//
//  HandwritingAnimator.swift
//  Margin
//
//  Created by Cerebro on 11/17/26.
//


import Foundation
import PencilKit
import UIKit

@MainActor
final class HandwritingAnimator {
    private weak var canvasView: PKCanvasView?

    init(canvasView: PKCanvasView) {
        self.canvasView = canvasView
    }

    func animate(
        strokes: [GeneratedStroke],
        pointsPerSecond: Double = 120
    ) async {
        guard let canvasView else { return }

        let ink = PKInk(.pen, color: .black)
        let frameDelay: UInt64 = 16_000_000

        for stroke in strokes {
            if Task.isCancelled { return }

            let points = stroke.locations
            guard points.count >= 2 else { continue }

            let existingStrokes = canvasView.drawing.strokes
            let step = max(1, Int(pointsPerSecond / 60))

            for endIndex in stride(
                from: 2,
                through: points.count,
                by: step
            ) {
                if Task.isCancelled { return }

                let visiblePoints = Array(
                    points.prefix(min(endIndex, points.count))
                )

                let pencilPoints = visiblePoints.enumerated().map {
                    index, location in
                    PKStrokePoint(
                        location: location,
                        timeOffset: TimeInterval(index) / pointsPerSecond,
                        size: CGSize(
                            width: stroke.width,
                            height: stroke.width
                        ),
                        opacity: 1,
                        force: 1,
                        azimuth: 0,
                        altitude: .pi / 2
                    )
                }

                let path = PKStrokePath(
                    controlPoints: pencilPoints,
                    creationDate: Date()
                )

                let partialStroke = PKStroke(
                    ink: ink,
                    path: path,
                    transform: .identity,
                    mask: nil
                )

                canvasView.drawing = PKDrawing(
                    strokes: existingStrokes + [partialStroke]
                )

                try? await Task.sleep(nanoseconds: frameDelay)
            }

            // Ensure the final point is included.
            let finalPoints = points.enumerated().map {
                index, location in
                PKStrokePoint(
                    location: location,
                    timeOffset: TimeInterval(index) / pointsPerSecond,
                    size: CGSize(
                        width: stroke.width,
                        height: stroke.width
                    ),
                    opacity: 1,
                    force: 1,
                    azimuth: 0,
                    altitude: .pi / 2
                )
            }

            let completedStroke = PKStroke(
                ink: ink,
                path: PKStrokePath(
                    controlPoints: finalPoints,
                    creationDate: Date()
                ),
                transform: .identity,
                mask: nil
            )

            canvasView.drawing = PKDrawing(
                strokes: existingStrokes + [completedStroke]
            )

            // Small pen lift between strokes.
            try? await Task.sleep(nanoseconds: 35_000_000)
        }
    }
}
