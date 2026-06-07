import Foundation
import SwiftUI

enum ArrowStyle: String, CaseIterable, Identifiable, Codable {
    case end = "À la fin"
    case start = "Au début"
    case bothSides = "Des deux côtés"
    case none = "Simple ligne"
    
    var id: String { self.rawValue }
}

// 1. Define the unique possible content types
enum ContentType: Equatable, Hashable, Codable {
    case rectangle(color: CodableColor)
    case text(text: String, color: CodableColor, size: CGFloat, font: String)
    case image(data: Data, ratio: CGFloat)
    case arrow(start: CGPoint, end: CGPoint, color: CodableColor, style: ArrowStyle, thickness: CGFloat)
    case transparent(val: Bool)
    case circle(color: CodableColor)
    case drawing(lines: [[CGPoint]], color: CodableColor, thickness: CGFloat)
}

// 2. The layer structure remains the global driver for positioning and dimensions
struct Layer: Identifiable, Hashable, Equatable, Codable {
    var id = UUID()
    var name: String
    
    // Common properties for ALL layers
    var x: CGFloat
    var y: CGFloat
    var width: CGFloat
    var height: CGFloat
    
    // Specific layer content
    var content: ContentType
    var opacity: Double? = 1.0
    
    var cropLeft: CGFloat? = 0
    var cropRight: CGFloat? = 0
    var cropTop: CGFloat? = 0
    var cropBottom: CGFloat? = 0
    
    var isVisible: Bool? = true
    
    enum CodingKeys: String, CodingKey {
        case name, x, y, width, height, content, opacity, cropLeft, cropRight, cropTop, cropBottom, isVisible
    }
}

    
