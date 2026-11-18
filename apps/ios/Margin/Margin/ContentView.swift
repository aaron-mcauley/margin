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
                
                Task {
                    do {
                        let answer = try await AIService().ask(recognizedText)
                        
                        await MainActor.run {
                            statusText = "Answer recieved"
                            
                            annotations.append(
                                AIAnnotation(
                                    text: answer,
                                    position: answerPosition
                                )
                            )
                            print("[AI] RESPONSE: \(answer)")
                        }
                    }   catch {
                        await MainActor.run {
                            statusText = "AI request failed"
                            print("[AI] ERROR: \(error)")
                        }
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
