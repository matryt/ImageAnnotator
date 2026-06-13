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
    
    var dimensions: CGSize {
        manager.getDimensions()
    }
    
    var body: some View {
        ZStack {
            ForEach(manager.getLayers().indices, id: \.self) { index in
                Group {
                    // 1. On passe par le subscript du manager pour l'accès sécurisé
                    let layer = manager[index]
                    
                    if (layer.isVisible ?? true) {
                        switch layer.content {
                        case .arrow, .drawing:
                            LayerElementView(layer: $manager[index])
                            
                        default:
                            LayerElementView(layer: $manager[index])
                                .position(x: manager[index].x, y: manager[index].y)
                                .gesture(
                                    index == 0 ? nil :
                                    DragGesture()
                                        .onChanged { gesture in
                                            if startX == 0 && startY == 0 {
                                                manager.registerStateForUndo(undoManager: undoManager, previousState: manager.getLayers())
                                                startX = manager[index].x
                                                startY = manager[index].y
                                            }
                                            
                                            let limitX = dimensions.width
                                            let limitY = dimensions.height
                                            
                                            let targetX = startX + gesture.translation.width
                                            let targetY = startY + gesture.translation.height
                                            
                                            manager[index].x = max(0, min(targetX, limitX))
                                            manager[index].y = max(0, min(targetY, limitY))
                                        }
                                        .onEnded { _ in
                                            startX = 0
                                            startY = 0
                                        }
                                )
                        }
                    } else {
                        // Safe fallback view token to let the compiler infer types properly when hidden
                        EmptyView()
                    }
                }
            }
        }
        .frame(width: CGFloat(dimensions.width), height: CGFloat(dimensions.height))
        .background(manager[0].name == "Arrière-plan" ? Color.clear : Color.white)
        .clipped()
    }
}
