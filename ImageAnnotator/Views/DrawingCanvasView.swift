//
//  DrawingCanvasView.swift
//  ImageAnnotator
//
//  Created by Mathieu CUVELIER on 07/06/2026.
//

import SwiftUI

struct DrawingCanvasView: View {
    @ObservedObject var manager: ProjectManager
    var undoManager: UndoManager?
    
    @Binding var startX: CGFloat
    @Binding var startY: CGFloat
    
    var canvasWidth: Double
    var canvasHeight: Double
    
    var body: some View {
        ZStack {
            ForEach(manager.layers.indices, id: \.self) { index in
                Group {
                    if (manager.layers[index].isVisible ?? true) {
                        switch manager.layers[index].content {
                        case .arrow, .drawing:
                            LayerElementView(layer: $manager.layers[index])
                            
                        default:
                            LayerElementView(layer: $manager.layers[index])
                                .position(x: manager.layers[index].x, y: manager.layers[index].y)
                                .gesture(
                                    index == 0 ? nil :
                                        DragGesture()
                                            .onChanged { gesture in
                                                if startX == 0 && startY == 0 {
                                                    // Capture history state on first click pointer interaction
                                                    manager.registerStateForUndo(undoManager: undoManager, previousState: manager.layers)
                                                    startX = manager.layers[index].x
                                                    startY = manager.layers[index].y
                                                }
                                                
                                                let limitX = manager.layers.first?.width ?? CGFloat(canvasWidth)
                                                let limitY = manager.layers.first?.height ?? CGFloat(canvasHeight)
                                                
                                                let targetX = startX + gesture.translation.width
                                                let targetY = startY + gesture.translation.height
                                                
                                                // Update properties directly on the observable object reference
                                                manager.layers[index].x = max(0, min(targetX, limitX))
                                                manager.layers[index].y = max(0, min(targetY, limitY))
                                            }
                                            .onEnded { _ in
                                                startX = 0
                                                startY = 0
                                            }
                                )
                        }
                    } else {
                        // Safe fallback fallback view token to let the compiler infer types properly when hidden
                        EmptyView()
                    }
                }
            }
        }
        .frame(
            width: manager.layers.first?.width ?? CGFloat(canvasWidth),
            height: manager.layers.first?.height ?? CGFloat(canvasHeight)
        )
        // Keep the UI logic for background rendering exactly the same
        .background(manager.layers.first?.name == "Arrière-plan" ? Color.clear : Color.white)
        .clipped()
    }
}
