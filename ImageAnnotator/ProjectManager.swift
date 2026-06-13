//
//  ProjectManager.swift
//  ImageAnnotator
//
//  Created by Mathieu CUVELIER on 07/06/2026.
//

import Foundation
import SwiftUI
import UniformTypeIdentifiers
import Combine

@MainActor
class ProjectManager: ObservableObject {
    @Published var canvasProject: CanvasProject
    
    init(canvasProject: CanvasProject) {
        self.canvasProject = canvasProject
    }
    
    // Custom internal clipboard for copy-paste operations
    var clipboardLayer: Layer? = nil
    
    func getLayers() -> [Layer] {
        return canvasProject.layers
    }
    
    func getLayer(index: Int) -> Layer? {
        return canvasProject.getLayer(index: index)
    }
    
    private func setLayers(_ layers: [Layer]) {
        canvasProject.layers = layers
    }
    
    // Core Undo state machine implementation
    func registerStateForUndo(undoManager: UndoManager?, previousState: [Layer]) {
        guard let undoManager = undoManager else { return }
        
        undoManager.registerUndo(withTarget: self) { manager in
            let currentState = self.getLayers()
            manager.registerStateForUndo(undoManager: undoManager, previousState: currentState)
            self.setLayers(previousState)
        }
    }
    
    func getDimensions() -> CGSize {
        return CGSize(width: canvasProject.width, height: canvasProject.height)
    }
    
    subscript(index: Int) -> Layer {
        get {
            // Sécurité enfant si l'index foire
            guard index >= 0 && index < canvasProject.layers.count else {
                return Layer(id: UUID(), name: "Fallback", x: 0, y: 0, width: 100, height: 100, content: .transparent(val: true))
            }
            return canvasProject.layers[index]
        }
        set {
            guard index >= 0 && index < canvasProject.layers.count else { return }
            canvasProject.layers[index] = newValue
        }
    }
}
