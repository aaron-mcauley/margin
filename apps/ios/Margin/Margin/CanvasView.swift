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
    var onTextRecognized: ((String) -> Void)?
    
    func makeCoordinator() -> Coordinator {
        Coordinator(
            handwritingManager: handwritingManager,
            onTextRecognized: onTextRecognized
        )
    }
    
    
    func makeUIView(context: Context) -> UIView {
        let container = UIView()
        container.backgroundColor = .clear
        canvasView.backgroundColor = .clear
        canvasView.isOpaque = false
        container.addSubview(canvasView)
        
        canvasView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            canvasView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            canvasView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            canvasView.topAnchor.constraint(equalTo: container.topAnchor),
            canvasView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        
        let overlay = UnderlineFeedbackOverlay()
        
        overlay.backgroundColor = .clear
        overlay.isUserInteractionEnabled = false
        
        container.addSubview(overlay)
        
        overlay.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            overlay.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            overlay.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            overlay.topAnchor.constraint(equalTo: container.topAnchor),
            overlay.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        
        context.coordinator.underlineOverlay = overlay
        
        canvasView.delegate = context.coordinator
        
        let underlineHoldGesture = UnderlineHoldGestureRecognizer()
        
        underlineHoldGesture.onHoldRecognized = { bounds, points in
            print("\n[CANVAS] UNDERLINE RECOGNIZED")
                print("bounds:", bounds)
                print("capturedPoints:", points.count)
            
                if let firstPoint = points.first,
                   let lastPoint = points.last {
                    print("firstPoint:", firstPoint)
                    print("lastPoint:", lastPoint)
                }
            context.coordinator.showUnderlineFeedback(points: points)
        }
        
        underlineHoldGesture.onConfirmed = { underlineBounds in
            
            context.coordinator.underlineConfirmed(
                bounds: underlineBounds 
            )
        }
        
        underlineHoldGesture.onCancelled = {
            context.coordinator.cancelUnderlineFeedback()
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
        
        return container
    }
    
    
    func updateUIView(_ uiView: UIView, context: Context) {
        canvasView.tool = isEraser
            ? PKEraserTool(.vector)
            : PKInkingTool(.pen, color: .black, width: 3)
        context.coordinator.updateCallback(onTextRecognized)
    }
    
    
    final class Coordinator: NSObject, PKCanvasViewDelegate, UIGestureRecognizerDelegate {
    
        init(handwritingManager: HandwritingManager,
             onTextRecognized: ((String) -> Void)?
        ) {
            self.handwritingManager = handwritingManager
            self.onTextRecognized = onTextRecognized
        }
        
        var underlineOverlay: UnderlineFeedbackOverlay?
        private let handwritingManager: HandwritingManager
        private var previousStrokeCount = 0
        private var pendingUnderlines: [PendingUnderline] = []
        private var onTextRecognized: ((String) -> Void)?
        
        private struct PendingUnderline {
            let id: UUID
            let gestureBounds: CGRect
            let confirmedAt: Date
        }
        
        private func removeConfirmedUnderline(_ underline: ConfirmedUnderline, from canvasView: PKCanvasView
        ) {
            let targetIndex = underline.strokeIndex
            
            DispatchQueue.main.async { [weak self, weak canvasView] in
            
                guard let self, let canvasView else { return }
                var strokes = canvasView.drawing.strokes
                
                guard strokes.indices.contains(targetIndex) else {
                    print("[CANVAS] UNDERLINE REMOVAL FAILED - INVALID INDEX")
                    return
                }
                
                // Verify we're still targeting the confirmed underline
                
                guard strokes[targetIndex].renderBounds == underline.stroke.renderBounds else {
                    print("[CANVAS] UNDERLINE REMOVAL FAILED - STROKE CHANGED")
                    return
                }
                
                strokes.remove(at: targetIndex)
                
                self.previousStrokeCount = strokes.count
                canvasView.drawing = PKDrawing(strokes: strokes)
                
                print("[CANVAS] CONFIRMED UNDERLINE REMOVED")
            }
        }
        
        func updateCallback(_ callback: ((String) -> Void)?) {
            onTextRecognized = callback
        }
        
        func showUnderlineFeedback(points: [CGPoint]) {
            underlineOverlay?.showUnderline(points: points)
        }
        
        func cancelUnderlineFeedback() {
            underlineOverlay?.cancelUnderline()
        }
        
        func underlineConfirmed( bounds: CGRect ) {
            
            let pending = PendingUnderline (
                id: UUID(),
                gestureBounds: bounds,
                confirmedAt: Date()
            )
            
            pendingUnderlines.append(pending)
            
            print("""
                [CANVAS] UNDERLINE QUEUED
                id: \(pending.id)
                bounds: \(pending.gestureBounds)
                pendingCount: \(pendingUnderlines.count)
                """)
        }
        
        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            return true
        }
        
        
        // MARK: - PencilKit Delegate

        func canvasViewDidEndUsingTool(
            _ canvasView: PKCanvasView
        ) {
            print("[CANVAS] DID END USING TOOL")

            processNewStrokes(in: canvasView)
        }

        func canvasViewDrawingDidChange(
            _ canvasView: PKCanvasView
        ) {
            print("[CANVAS] DRAWING DID CHANGE")

            processNewStrokes(in: canvasView)
        }
        
        private func processNewStrokes(
            in canvasView: PKCanvasView
        ) {
            let strokes = canvasView.drawing.strokes

            // Handle drawing shrinkage.
            if strokes.count < previousStrokeCount {
                print("[CANVAS] STROKE COUNT DECREASED")
                previousStrokeCount = strokes.count
                return
            }

            guard strokes.count > previousStrokeCount else {
                return
            }

            let newStrokeIndices = previousStrokeCount..<strokes.count

            // Prevent duplicate processing from delegate callbacks.
            previousStrokeCount = strokes.count

            for index in newStrokeIndices {

                let stroke = strokes[index]

                print("""
                [CANVAS] NEW STROKE
                index: \(index)
                bounds: \(stroke.renderBounds)
                pendingCount: \(pendingUnderlines.count)
                """)

                handwritingManager.strokeCompleted(stroke)

                guard !pendingUnderlines.isEmpty else {
                    print("[CANVAS] NORMAL HANDWRITING")
                    continue
                }

                // Compare against every pending underline.
                guard let matchIndex = pendingUnderlines.firstIndex(
                    where: { pending in
                        underlineStrokeMatches(
                            stroke: stroke,
                            gestureBounds: pending.gestureBounds
                        )
                    }
                ) else {
                    print(
                        "[CANVAS] NO UNDERLINE MATCH — KEEPING PENDING CONFIRMATIONS"
                    )
                    continue
                }

                // Remove only the matched confirmation.
                let matched = pendingUnderlines.remove(
                    at: matchIndex
                )

                print("""
                [CANVAS] UNDERLINE MATCHED
                confirmationID: \(matched.id)
                strokeIndex: \(index)
                remainingPending: \(pendingUnderlines.count)
                """)

                let confirmedUnderline = ConfirmedUnderline(
                    stroke: stroke,
                    strokeIndex: index,
                    gestureBounds: matched.gestureBounds
                )

                Task { @MainActor in
                    
                    // Extract handwriting before removing the underline
                    await testSmartCrop(
                        underline: confirmedUnderline,
                        canvasView: canvasView
                    )
                    
                    // Remove only the confirmed black underline
                    removeConfirmedUnderline(confirmedUnderline, from: canvasView)
                
                    // Fade out the blue feedback
                    underlineOverlay?.hideUnderline()
                }
            }
        }
        
        private func underlineStrokeMatches(
            stroke: PKStroke,
            gestureBounds: CGRect
        ) -> Bool {

            let strokeBounds = stroke.renderBounds

            print("[MATCH] START")
            print("gestureBounds:", gestureBounds)
            print("strokeBounds:", strokeBounds)

            // MARK: Horizontal overlap

            let horizontalIntersection =
                min(strokeBounds.maxX, gestureBounds.maxX) -
                max(strokeBounds.minX, gestureBounds.minX)

            guard horizontalIntersection > 0 else {
                print("[MATCH] FAILED — NO HORIZONTAL OVERLAP")
                return false
            }

            let shorterWidth = min(
                strokeBounds.width,
                gestureBounds.width
            )

            guard shorterWidth > 0 else {
                print("[MATCH] FAILED — INVALID WIDTH")
                return false
            }

            let horizontalOverlapRatio =
                horizontalIntersection / shorterWidth

            // MARK: Vertical center

            let verticalCenterDistance = abs(
                strokeBounds.midY - gestureBounds.midY
            )

            // PencilKit renderBounds includes ink thickness,
            // so compare centers rather than rectangle area.
            let verticalTolerance = max(
                strokeBounds.height,
                gestureBounds.height
            )

            // MARK: Width similarity

            let widthRatio =
                min(strokeBounds.width, gestureBounds.width) /
                max(strokeBounds.width, gestureBounds.width)

            print("[MATCH] METRICS")
            print("horizontalOverlapRatio:", horizontalOverlapRatio)
            print("verticalCenterDistance:", verticalCenterDistance)
            print("verticalTolerance:", verticalTolerance)
            print("widthRatio:", widthRatio)

            let matches =
                horizontalOverlapRatio >= 0.9 &&
                verticalCenterDistance <= verticalTolerance &&
                widthRatio >= 0.8

            print(
                matches
                    ? "[MATCH] PASSED"
                    : "[MATCH] FAILED — IDENTITY CHECK"
            )

            return matches
        }
        func testSmartCrop(
            underline: ConfirmedUnderline,
            canvasView: PKCanvasView
        ) async {
            
            print("""
            
            [SMARTCROP] REQUEST STARTED
            underlineIndex: \(underline.strokeIndex)
            underlineBounds: \(underline.stroke.renderBounds)
            drawingStrokeCount: \(canvasView.drawing.strokes.count)
            """)
            
            let smartCropService = SmartCropService()
            
            guard let result = smartCropService.cropQuestion(
                above: underline,
                in: canvasView.drawing
            ) else {
                print("[SMARTCROP] FAILED — NO CROP RETURNED")
                return
            }
            
            print("""
            [SMARTCROP] SUCCESS
            cropBounds: \(result.bounds)
            averageLineHeight: \(result.averageLineHeight)
            imageSize: \(result.image.size)
            """)
            
            print("[OCR] STARTED")
            
            do {
                let ocrService = VisionOCRService()
                
                let recognizedText = try await ocrService.recognizeText(
                    from: result.image
                )
                onTextRecognized?(recognizedText)

                
                print("""
                [OCR] SUCCESS
                result: \(recognizedText)
                
                """)
                
            } catch {
                
                print("""
                [OCR] FAILED
                error: \(error)
                
                """)
            }
            
        }
    }
}
