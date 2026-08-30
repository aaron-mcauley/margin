//
//  HandwritingManager.swift
//  Margin
//
//  Created by Triz on 7/27/26.
//

import PencilKit

final class HandwritingManager {
    func strokeCompleted(_ stroke: PKStroke) {
        let bounds = stroke.renderBounds

        print("STROKE COMPLETED")
        print("width:", bounds.width)
        print("height:", bounds.height)

        if UnderlineDetector.isUnderline(stroke) {
            print("UNDERLINE DETECTED")
        }
    }
}
