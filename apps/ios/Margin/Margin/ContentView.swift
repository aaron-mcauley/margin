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
    @State private var isSelecting = false
    @State private var lassoPoints: [CGPoint] = []
    @State private var lassoClosed = false
    @State private var selectionRect: CGRect = .zero
    @State private var annotations: [AIAnnotation] = []
    @State private var isEraser = false
    @State private var resizeStartWidth: CGFloat = 320
    @State private var cropPreview: UIImage?


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

            CanvasView(canvasView: $canvasView,
                isEraser: isEraser,
                       handwritingManager: handwritingManager
            )
            .ignoresSafeArea()

            if isSelecting {
                Color.clear
                    .contentShape(Rectangle())
                    .ignoresSafeArea()
                    .gesture(
                        DragGesture(
                            minimumDistance: 0,
                            coordinateSpace: .named("page")
                                   )
                            .onChanged { value in
                                lassoPoints.append(value.location)
                            }
                            .onEnded { _ in
                                lassoClosed = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                                    isSelecting = false
                                    finishLasso()
                                }
                            }
                    )

                Path { path in
                    guard let firstPoint = lassoPoints.first else { return }

                    path.move(to: firstPoint)

                    for point in lassoPoints.dropFirst() {
                        path.addLine(to: point)
                    }

                    if lassoClosed {
                        path.closeSubpath()
                    }
                }
                .stroke(
                    Color.blue,
                    style: StrokeStyle(
                        lineWidth: 3,
                        dash: [8, 5]
                    )
                )
                .ignoresSafeArea()
            }

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
                    
                    Button {
                        isSelecting.toggle()
                        lassoPoints.removeAll()
                        lassoClosed = false
                        statusText = isSelecting ? "Circle a question" : "Ready"
                    } label: {
                        Image(systemName: "sparkles")
                            .foregroundColor(isSelecting ? .white : .black)
                            .padding(10)
                            .background(
                                isSelecting ? Color.black : Color.clear
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
    }
    
    func askAi() {
        let fullImage = canvasView.drawing.image(
            from: canvasView.bounds,
            scale: UIScreen.main.scale
        )

        guard selectionRect.width > 0,
              selectionRect.height > 0 else {
            statusText = "No valid selection"
            return
        }

        let scale = UIScreen.main.scale

        let cropRect = CGRect(
            x: selectionRect.origin.x * scale,
            y: selectionRect.origin.y * scale,
            width: selectionRect.width * scale,
            height: selectionRect.height * scale
        )

        guard let cgImage = fullImage.cgImage?.cropping(to: cropRect) else {
            statusText = "Crop failed"
            return
        }

        let croppedImage = UIImage(cgImage: cgImage)

        statusText = "Thinking..."

        Task {
            do {
                print("Sending image to OpenAI...")

                let response = try await AIService()
                    .imageInquiry(croppedImage)

                await MainActor.run {

                    let newAnnotation = AIAnnotation(
                        text: response,
                        position: CGPoint(
                            x: selectionRect.minX + (max(selectionRect.width, 260) / 2),
                            y: selectionRect.maxY + 3
                        ),
                        opacity: 0,
                        width: max(selectionRect.width, 260)
                    )

                    annotations.append(newAnnotation)

                    let newIndex = annotations.count - 1

                    withAnimation(.easeInOut(duration: 1.0)) {
                        annotations[newIndex].opacity = 1.0
                    }

                    statusText = "Answer ready"
                }

            } catch {
                await MainActor.run {
                    statusText = "OpenAI Error"
                    print(error)
                }
            }
        }
    }
    
    /*
    func askAi() {
        statusText = "Thinking..."

        let fakeResponse = """
        SB 1383 requires California cities and counties to reduce organic waste disposal, expand food recovery programs, provide organics collection, conduct outreach, monitor compliance, and report progress. In simple terms, local governments must help divert food and green waste from landfills to reduce methane emissions.
        """

        let newAnnotation = AIAnnotation(
            text: fakeResponse,
            position: CGPoint(
                x: selectionRect.midX,
                y: selectionRect.maxY + 60
            ),
            opacity: 0,
            width: max(selectionRect.width, 260)
        )

        annotations.append(newAnnotation)

        let newIndex = annotations.count - 1

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {

            withAnimation(.easeInOut(duration: 1.0)) {
                annotations[newIndex].opacity = 1.0
            }

            statusText = "Answer ready"
        }
    }
    */
    func finishLasso() {
        guard !lassoPoints.isEmpty else {
            statusText = "No selection"
            return
        }

        let minX = lassoPoints.map { $0.x }.min() ?? 0
        let maxX = lassoPoints.map { $0.x }.max() ?? 0
        let minY = lassoPoints.map { $0.y }.min() ?? 0
        let maxY = lassoPoints.map { $0.y }.max() ?? 0

        selectionRect = CGRect(
            x: minX,
            y: minY,
            width: maxX - minX,
            height: maxY - minY
        )

        statusText = "Selected: \(Int(selectionRect.width)) x \(Int(selectionRect.height))"


        askAi()
    }
}

#Preview {
    ContentView()
}
