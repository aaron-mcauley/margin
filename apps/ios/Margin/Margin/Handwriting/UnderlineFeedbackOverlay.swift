//
//  Untitled.swift
//  Margin
//
//  Created by Triz on 11/8/26.
//

import UIKit

@MainActor
final class UnderlineFeedbackOverlay: UIView {
    
    private let underlineLayer = CAShapeLayer()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        isUserInteractionEnabled = false
        backgroundColor = .clear
        isOpaque = false
        
        underlineLayer.fillColor = UIColor.clear.cgColor
        underlineLayer.strokeColor = UIColor.systemBlue.cgColor
        underlineLayer.lineWidth = 3
        underlineLayer.lineCap = .round
        underlineLayer.lineJoin = .round
        underlineLayer.opacity = 0
        
        layer.addSublayer(underlineLayer)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func showUnderline(points: [CGPoint]) {
        guard points.count >= 2 else {
            return
        }
        
        underlineLayer.removeAllAnimations()
        
        let path = UIBezierPath()
        path.move(to: points[0])
        
        for point in points.dropFirst() {
            path.addLine(to: point)
        }
        
        underlineLayer.path = path.cgPath
        underlineLayer.opacity = 2
        
        let animation = CABasicAnimation(keyPath: "opacity")
        animation.fromValue = 0
        animation.toValue = 1
        animation.duration = 0.2
        animation.timingFunction = CAMediaTimingFunction( name: .easeInEaseOut)
        
        underlineLayer.add(animation, forKey: "underlineAppear")
    }
    
    func hideUnderline(completion: (() -> Void)? = nil) {
        underlineLayer.removeAllAnimations()
        
        let animation = CABasicAnimation(keyPath: "opacity")
        animation.fromValue = underlineLayer.presentation()?.opacity ?? underlineLayer.opacity
        animation.toValue = 0
        animation.duration = 0.2
        animation.timingFunction = CAMediaTimingFunction (
            name: .easeInEaseOut
            )
        
        CATransaction.begin()
        
        CATransaction.setCompletionBlock { [weak self] in
            self?.underlineLayer.opacity = 0
            self?.underlineLayer.path = nil
            completion?()
        }
        
        underlineLayer.opacity = 0
        underlineLayer.add(animation, forKey: "underlineDisappear")
        
        CATransaction.commit()
        
    }
    
    func cancelUnderline() {
        underlineLayer.removeAllAnimations()
        underlineLayer.opacity = 0
        underlineLayer.path = nil
    }
 }
