//
//  UnderlineDetector.swift
//  Margin
//
//  Created by Triz on 7/27/26.
//

import PencilKit

struct UnderlineDetector{
    static func isUnderline(_ stroke: PKStroke) -> Bool {
        let bounds = stroke.renderBounds
        let width = bounds.width
        let height = bounds.height
        return width > 100 && height < 40
    }
}

