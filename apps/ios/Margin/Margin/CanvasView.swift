//
//  CanvasView.swift
//  Margin
//
//  Created by Triz on 6/16/26.
//

import SwiftUI
import PencilKit

struct CanvasView: UIViewRepresentable {
    @Binding var canvasView: PKCanvasView
    var isEraser: Bool
    
    func makeUIView(context: Context) -> PKCanvasView {
        canvasView.drawingPolicy = .pencilOnly
        canvasView.backgroundColor = .clear
        canvasView.isOpaque = false
      return canvasView
    }
    
    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        if isEraser {
            uiView.tool = PKEraserTool(.vector)
        } else {
            uiView.tool = PKInkingTool(
                .pen,
                color: UIColor(white: 0.02, alpha: 1.0),
                width: 5
            )
        }
    }
}

