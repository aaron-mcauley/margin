//
//  LegalPadBackground.swift
//  Margin
//
//  Created by Triz on 6/22/26.
//

import SwiftUI

struct LegalPadBackground: View {
    let lineSpacing: CGFloat = 28
    let marginX: CGFloat = 70
    
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                Color(red: 1.0, green: 0.97, blue: 0.70)
                    .ignoresSafeArea()
                
                Path {path in
                    path.move(to: CGPoint(x: marginX, y: 0))
                    path.addLine(to: CGPoint(x: marginX, y: geo.size.height))
                }
                .stroke(Color.red.opacity(0.45), lineWidth: 1)
                
                ForEach(Array(stride(from: lineSpacing, through: geo.size.height, by: lineSpacing)), id: \.self) { y in
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: geo.size.width, y: y))
                    }
                    .stroke(Color.blue.opacity(0.25), lineWidth: 1)
                }
            }
        }
    }
}
