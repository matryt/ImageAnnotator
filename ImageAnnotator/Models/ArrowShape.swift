//
//  ArrowShape.swift
//  ImageAnnotator
//
//  Created by Mathieu CUVELIER on 07/06/2026.
//

import SwiftUI

struct ArrowShape: Shape {
    var start: CGPoint
    var end: CGPoint
    var arrowStyle: ArrowStyle
    var thickness: CGFloat
    
    var animatableData: AnimatablePair<CGPoint.AnimatableData, CGPoint.AnimatableData> {
        get { AnimatablePair(start.animatableData, end.animatableData) }
        set {
            start.animatableData = newValue.first
            end.animatableData = newValue.second
        }
    }
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: start)
        path.addLine(to: end)
        
        let dX = end.x - start.x
        let dY = end.y - start.y
        let angle = atan2(dY, dX)
        
        // Dynamic arrowhead dimensions based on lines thickness properties
        let headLength = max(thickness * 3, 15)
        let headAngle = CGFloat.pi / 6
        
        // 1. Draw end arrowhead cap if enabled
        if arrowStyle == .end || arrowStyle == .bothSides {
            let arrowTip1 = CGPoint(x: end.x - headLength * cos(angle - headAngle), y: end.y - headLength * sin(angle - headAngle))
            let arrowTip2 = CGPoint(x: end.x - headLength * cos(angle + headAngle), y: end.y - headLength * sin(angle + headAngle))
            
            path.move(to: end)
            path.addLine(to: arrowTip1)
            path.move(to: end)
            path.addLine(to: arrowTip2)
        }
        
        // 2. Draw start arrowhead cap if enabled
        if arrowStyle == .start || arrowStyle == .bothSides {
            let arrowTip1 = CGPoint(x: start.x + headLength * cos(angle - headAngle), y: start.y + headLength * sin(angle - headAngle))
            let arrowTip2 = CGPoint(x: start.x + headLength * cos(angle + headAngle), y: start.y + headLength * sin(angle + headAngle))
            
            path.move(to: start)
            path.addLine(to: arrowTip1)
            path.move(to: start)
            path.addLine(to: arrowTip2)
        }
        
        return path
    }
}
