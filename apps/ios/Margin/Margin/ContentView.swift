//
//  ContentView.swift
//  Margin
//
//  Created by Triz on 6/15/26.
// 

import SwiftUI
import PencilKit

struct ContentView: View {
    private let handwritingManager = HandwritingManager()
    
    @State private var canvasView = PKCanvasView()
    @State private var statusText = "Ready"
    @State private var annotations: [AIAnnotation] = []
    @State private var isEraser = false
    
    struct AIAnnotation: Identifiable {
        let id = UUID()
        var text: String
        var position: CGPoint
        var opacity: Double = 1.0
        var width: CGFloat = 320
    }
    
    var body: some View {
        ZStack {
            LegalPadBackground()
                .ignoresSafeArea()
            
            CanvasView(canvasView: $canvasView, isEraser: isEraser, handwritingManager: handwritingManager, onTextRecognized: {
                recognizedText, answerPosition in statusText = "Thinking..."
                
                
                Task { @MainActor in
                    do {
                        statusText = "Thinking..."
                        
                        // 1. Get the AI answer.
                        let answer = try await AIService().ask(recognizedText)
                        
                        statusText = "Generating handwriting..."
                        
                        // 2. Generate ordered strokes.
                        let placement = HandwritingPlacement(
                            x: answerPosition.x,
                            y: answerPosition.y,
                            averageLineHeight: 24,
                            width: 2,
                            color: "#000000",
                            maxWidth: max(
                                100,
                                canvasView.bounds.width - answerPosition.x - 20
                            )
                        )
                        
                        let strokes = try await HandwritingService().generate(
                            text: answer,
                            placement: placement
                        )
                        
                        print("[HANDWRITING] Generated \(strokes.count) strokes")
                        
                        // 3. Draw the strokes onto PencilKit.
                        statusText = "Writing..."
                        
                        let animator = HandwritingAnimator(
                            canvasView: canvasView
                        )
                        
                        await animator.animate(strokes: strokes)
                        
                        statusText = "Ready"
                        
                    } catch {
                        statusText = "Handwriting failed"
                        print("[HANDWRITING] ERROR: \(error)")
                    }
                }
            })

                       
            ForEach($annotations) { $annotation in
                ZStack(alignment: .topTrailing) {
                    
                    Text(annotation.text)
                        .font(.system(size: 16))
                        .foregroundColor(.black)
                        .multilineTextAlignment(.leading)
                        .frame(width: annotation.width, alignment: .leading)
                    
                    Button {
                        annotations.removeAll { $0.id == annotation.id }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.gray)
                    }
                    .offset(x: 14, y: -14)
                }
                .position(annotation.position)
                .opacity(annotation.opacity)
                .simultaneousGesture(
                    DragGesture()
                        .onChanged { value in
                            annotation.position = value.location
                        }
                )
            }
            
            .coordinateSpace(name: "page")
            VStack {
                HStack {
                    Text("Margin")
                        .font(.headline)
                        .padding(10)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    
                    Spacer()
                    
                    Button {
                        isEraser = false
                    } label: {
                        Image(systemName: "pencil")
                            .foregroundColor(isEraser ? .black : .white)
                            .padding(10)
                            .background(
                                isEraser ? Color.clear : Color.black
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.black, lineWidth: 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    
                    Button {
                        isEraser = true
                    } label: {
                        Image(systemName: "eraser")
                            .foregroundColor(isEraser ? .white : .black)
                            .padding(10)
                            .background(
                                isEraser ? Color.black : Color.clear
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.black, lineWidth: 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
                
                Spacer()
                
                Text(statusText)
                    .font(.caption)
                    .padding(8)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .padding()
        }
        .preferredColorScheme(.light)
    }
}
  

#Preview {
    ContentView()
}
