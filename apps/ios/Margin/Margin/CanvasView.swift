//
//  CanvasView.swift
//  Margin
//
//  Created by Triz on 6/16/26.
//

import SwiftUI
import PencilKit

struct CanvasView: UIViewRepresentable {

    // The actual PKCanvasView owned by ContentView
    @Binding var canvasView: PKCanvasView

    // Current tool selected in ContentView
    var isEraser: Bool

    // Handles completed handwriting strokes
    let handwritingManager: HandwritingManager


    func makeCoordinator() -> Coordinator {
        Coordinator(
            handwritingManager: handwritingManager
        )
    }


    func makeUIView(context: Context) -> PKCanvasView {

        canvasView.delegate = context.coordinator
        
        let underlineHoldGesture = UnderlineHoldGestureRecognizer()
        
        underlineHoldGesture.onHoldRecognized = {
        }
        
        underlineHoldGesture.onConfirmed = {
        }
        
        underlineHoldGesture.onCancelled = {
        }

        underlineHoldGesture.cancelsTouchesInView = false
        underlineHoldGesture.delegate = context.coordinator

        canvasView.addGestureRecognizer(underlineHoldGesture)
        
        

        // Apple Pencil only
        canvasView.drawingPolicy = .anyInput

        canvasView.backgroundColor = .clear
        canvasView.isOpaque = false

        canvasView.tool = PKInkingTool(
            .pen,
            color: .black,
            width: 3
        )

        return canvasView
    }


    func updateUIView(
        _ canvasView: PKCanvasView,
        context: Context
    ) {

        if isEraser {

            canvasView.tool = PKEraserTool(.vector)

        } else {

            canvasView.tool = PKInkingTool(
                .pen,
                color: .black,
                width: 3
            )
        }
    }


    final class Coordinator: NSObject, PKCanvasViewDelegate, UIGestureRecognizerDelegate {

        private let handwritingManager: HandwritingManager

        private var previousStrokeCount = 0


        init(handwritingManager: HandwritingManager) {
            self.handwritingManager = handwritingManager
        }
        
        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            return true
        }

        func canvasViewDidEndUsingTool(
            _ canvasView: PKCanvasView
        ) {

            let strokes = canvasView.drawing.strokes

            defer {
                previousStrokeCount = strokes.count
            }

            guard strokes.count > previousStrokeCount,
                  let newestStroke = strokes.last else {
                return
            }

            handwritingManager.strokeCompleted(newestStroke)
        }
    }
}
