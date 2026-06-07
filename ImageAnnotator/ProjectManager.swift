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
    @Published var layers: [Layer] = []
    
    // Custom internal clipboard for copy-paste operations
    var clipboardLayer: Layer? = nil
    
    // Core Undo state machine implementation
    func registerStateForUndo(undoManager: UndoManager?, previousState: [Layer]) {
        guard let undoManager = undoManager else { return }
        
        undoManager.registerUndo(withTarget: self) { manager in
            let currentState = manager.layers
            manager.registerStateForUndo(undoManager: undoManager, previousState: currentState)
            manager.layers = previousState
        }
    }
}
