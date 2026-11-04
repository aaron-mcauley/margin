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
        private var pendingUnderlineGestureBounds: CGRect?
        private var pendingUnderlineAfterStrokeIndex: Int?
        private let onCropCreated: ((UIImage) -> Void)?
        
        init(handwritingManager: HandwritingManager,
             onCropCreated: ((UIImage) -> Void)?
        ) {
            self.handwritingManager = handwritingManager
            self.onCropCreated = onCropCreated
        }
        
        func underlineConfirmed(
            bounds: CGRect
        ) {
            pendingUnderlineGestureBounds = bounds
            pendingUnderlineAfterStrokeIndex = previousStrokeCount - 1

            print("\n[CANVAS] UNDERLINE CONFIRMATION RECEIVED")
            print("gestureBounds:", bounds)
            print(
                "lastKnownStrokeIndex:",
                pendingUnderlineAfterStrokeIndex ?? -1
            )
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

            print("\n[CANVAS] DID END USING TOOL")
            print("previousStrokeCount:", previousStrokeCount)
            print("currentStrokeCount:", strokes.count)
            print(
                "pendingUnderline:",
                pendingUnderlineGestureBounds != nil
            )

            defer {
                previousStrokeCount = strokes.count

                print("[CANVAS] STROKE COUNT UPDATED")
                print("previousStrokeCount:", previousStrokeCount)
            }

            guard strokes.count > previousStrokeCount else {
                print("[CANVAS] NO NEW STROKE — EXITING")
                return
            }

            // Process EVERY stroke PencilKit has committed since
            // the previous callback instead of assuming strokes.last
            // is the stroke we're interested in.
            let newStrokeIndices = previousStrokeCount..<strokes.count

            for index in newStrokeIndices {

                let stroke = strokes[index]

                print("\n[CANVAS] NEW STROKE")
                print("index:", index)
                print("bounds:", stroke.renderBounds)
                print("width:", stroke.renderBounds.width)
                print("height:", stroke.renderBounds.height)

                handwritingManager.strokeCompleted(stroke)

                guard let gestureBounds = pendingUnderlineGestureBounds else {
                    print(
                        "[CANVAS] NO PENDING UNDERLINE — NORMAL HANDWRITING"
                    )
                    continue
                }

                print("[CANVAS] PENDING UNDERLINE EXISTS")
                print("gestureBounds:", gestureBounds)
                print("candidateStrokeBounds:", stroke.renderBounds)

                guard underlineStrokeMatches(
                    stroke: stroke,
                    gestureBounds: gestureBounds
                ) else {
                    // IMPORTANT:
                    // Do NOT clear pendingUnderlineGestureBounds here.
                    //
                    // This stroke isn't the confirmed underline.
                    // PencilKit may commit the actual underline later.
                    print(
                        "[CANVAS] CANDIDATE DID NOT MATCH — KEEPING PENDING UNDERLINE"
                    )

                    continue
                }

                print("[CANVAS] UNDERLINE STROKE MATCHED")
                print("matchedStrokeIndex:", index)

                // NOW we've actually identified the PKStroke corresponding
                // to the confirmed gesture. Only now consume the pending state.
                pendingUnderlineGestureBounds = nil

                let confirmedUnderline = ConfirmedUnderline(
                    stroke: stroke,
                    strokeIndex: index,
                    gestureBounds: gestureBounds
                )

                Task {
                    await testSmartCrop(
                        underline: confirmedUnderline,
                        canvasView: canvasView
                    )
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
