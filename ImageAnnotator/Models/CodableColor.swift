//
//  CodableColor.swift
//  ImageAnnotator
//
//  Created by Mathieu CUVELIER on 07/06/2026.
//

import SwiftUI


struct CodableColor: Codable, Hashable, Equatable {
    var red: Double
    var green: Double
    var blue: Double
    var alpha: Double

    // Converts a SwiftUI Color into a CodableColor
    init(_ color: Color) {
        let nsColor = NSColor(color)
        if let rgbColor = nsColor.usingColorSpace(.sRGB) {
            self.red = Double(rgbColor.redComponent)
            self.green = Double(rgbColor.greenComponent)
            self.blue = Double(rgbColor.blueComponent)
            self.alpha = Double(rgbColor.alphaComponent)
        } else {
            // Fallback in case conversion fails (defaults to a white background)
            self.red = 1.0
            self.green = 1.0
            self.blue = 1.0
            self.alpha = 1.0
        }
    }

    // Converts the CodableColor back into a real SwiftUI Color
    var asColor: Color {
        Color(nsColor: NSColor(red: CGFloat(red), green: CGFloat(green), blue: CGFloat(blue), alpha: CGFloat(alpha)))
    }
}
