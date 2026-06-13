//
//  CanvasProject.swift
//  ImageAnnotator
//
//  Created by Mathieu CUVELIER on 13/06/2026.
//

import Foundation

struct CanvasProject: Codable {
    var width: Double
    var height: Double
    var layers: [Layer]
    
    func getLayer(index: Int) -> Layer? {
        if index < layers.count {
            return layers[index]
        }
        return nil
    }
}
