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
    
    // --- LIAISON DU MODE CROP ---
    @Binding var isCropModeActive: Bool
    @Binding var cropSelectionRect: CGRect
    @Binding var cropTargetAll: Bool
    
    @State private var isDrawingCrop: Bool = false
    @State private var cropCurrentPoint: CGPoint = .zero
    
    var dimensions: CGSize {
        manager.getDimensions()
    }
    
    var body: some View {
        ZStack {
            // 1. Les calques standards de ton application
            ForEach(manager.getLayers().indices, id: \.self) { index in
                Group {
                    let layer = manager[index]
                    
                    if (layer.isVisible ?? true) {
                        
                        let cLeft = layer.cropLeft ?? 0
                        let cTop = layer.cropTop ?? 0
                        let cRight = layer.cropRight ?? 0
                        let cBottom = layer.cropBottom ?? 0
                        
                        let maskWidth = max(0, layer.width - cLeft - cRight)
                        let maskHeight = max(0, layer.height - cTop - cBottom)
                        
                        let isLayerCropped = cLeft > 0 || cTop > 0 || cRight > 0 || cBottom > 0
                        
                        switch layer.content {
                        case .arrow, .drawing:
                            // Rendu vectoriel brut : la découpe a altéré les points dans ContentView
                            LayerElementView(layer: $manager[index])
                                .disabled(isCropModeActive)
                            
                        default:
                            // Rendu par pochoir : on tronque le visuel (Rectangle, Cercle, Image, Texte)
                            LayerElementView(layer: $manager[index])
                                .disabled(isCropModeActive)
                                .if(isLayerCropped) { view in
                                    view.mask(
                                        Rectangle()
                                            .frame(width: maskWidth, height: maskHeight)
                                            .position(x: cLeft + maskWidth / 2, y: cTop + maskHeight / 2)
                                    )
                                }
                                .position(x: layer.x, y: layer.y)
                                .gesture(
                                    isCropModeActive ? nil : (
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
                                )
                        }
                    } else {
                        EmptyView()
                    }
                }
            }
            
            // 2. Le rectangle de sélection tracé à la souris (S'affiche par-dessus le projet)
            if isCropModeActive && isDrawingCrop {
                Path { path in
                    path.addRect(cropSelectionRect)
                }
                .stroke(cropTargetAll ? Color.blue : Color.orange, style: StrokeStyle(lineWidth: 2, dash: [5]))
                .background(
                    Rectangle()
                        .fill(cropTargetAll ? Color.blue.opacity(0.1) : Color.orange.opacity(0.1))
                        .frame(width: cropSelectionRect.width, height: cropSelectionRect.height)
                        .position(x: cropSelectionRect.midX, y: cropSelectionRect.midY)
                )
            }
        }
        .frame(width: CGFloat(dimensions.width), height: CGFloat(dimensions.height))
        .background(manager[0].name == "Arrière-plan" ? Color.clear : Color.white)
        .clipped()
        .gesture(
            isCropModeActive ?
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    if !isDrawingCrop {
                        startX = value.startLocation.x
                        startY = value.startLocation.y
                        isDrawingCrop = true
                    }
                    cropCurrentPoint = value.location
                    
                    let minX = min(startX, cropCurrentPoint.x)
                    let minY = min(startY, cropCurrentPoint.y)
                    let width = abs(cropCurrentPoint.x - startX)
                    let height = abs(cropCurrentPoint.y - startY)
                    
                    cropSelectionRect = CGRect(x: minX, y: minY, width: width, height: height)
                }
                .onEnded { _ in
                    isDrawingCrop = false
                }
            : nil
        )
    }
}

private extension View {
    @ViewBuilder func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition { transform(self) } else { self }
    }
}
