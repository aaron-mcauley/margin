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
    var onCropCreated: ((UIImage) -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(
            handwritingManager: handwritingManager,
            onCropCreated: onCropCreated
        )
    }


    func makeUIView(context: Context) -> PKCanvasView {

        canvasView.delegate = context.coordinator
        
        let underlineHoldGesture = UnderlineHoldGestureRecognizer()
        
        underlineHoldGesture.onHoldRecognized = {
        }
        
        underlineHoldGesture.onConfirmed = { underlineBounds in

            context.coordinator.underlineConfirmed(
                bounds: underlineBounds
            )
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
        private var pendingConfirmedUnderlineBounds: CGRect?
        
        private let onCropCreated: ((UIImage) -> Void)?
        
        init(handwritingManager: HandwritingManager,
             onCropCreated: ((UIImage) -> Void)?
        ) {
            self.handwritingManager = handwritingManager
            self.onCropCreated = onCropCreated
        }
        
        func underlineConfirmed (
            bounds: CGRect
        ) {
            print("CONFIRMED BOUNDS RECEIVED:", bounds)
            pendingConfirmedUnderlineBounds = bounds
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
            
            if pendingConfirmedUnderlineBounds != nil {
                testSmartCrop(
                    underline: newestStroke,
                    canvasView: canvasView
                )
                
                pendingConfirmedUnderlineBounds = nil
            }
        }
        
        func testSmartCrop(
            underline: PKStroke,
            canvasView: PKCanvasView
        ) {
            
            let smartCropService = SmartCropService()
            
            guard let result = smartCropService.cropQuestion(
                above: underline,
                in: canvasView.drawing
            ) else {
                print("SMART CROP TEST: Crop failed")
                return
            }
            
            print("SMART CROP TEST: SUCCESS")
            print("Crop bounds:", result.bounds)
            print("Average line height:", result.averageLineHeight)
            print("Image size:", result.image.size)
            UIImageWriteToSavedPhotosAlbum(
                result.image,
                nil,
                nil,
                nil
            )
        }
    }
}
