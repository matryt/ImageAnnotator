//
//  LayerElementView.swift
//  ImageAnnotator
//
//  Created by Mathieu CUVELIER on 07/06/2026.
//

import SwiftUI

struct LayerElementView: View {
    @Binding var layer: Layer
    @State private var isEditing: Bool = false
    @State private var dragOffset: CGSize = .zero
    
    @Environment(\.undoManager) var undoManager
    
    var body: some View {
        ZStack {
            switch layer.content {
            case .rectangle(let color, let isFilled, let strokeThickness):
                ZStack(alignment: .bottomTrailing) {
                    if isFilled {
                        Rectangle()
                            .foregroundStyle(color.asColor)
                            .frame(width: layer.width, height: layer.height)
                            .opacity(layer.opacity ?? 1)
                    } else {
                        Rectangle()
                            .stroke(color.asColor, lineWidth: strokeThickness)
                            .frame(width: layer.width, height: layer.height)
                            .opacity(layer.opacity ?? 1)
                    }
                    
                    if isEditing {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 20, height: 20)
                            .offset(x: 6, y: 6) // Aligne pile sur le coin
                            .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        // On calcule la nouvelle taille selon le déplacement de la souris
                                        let newWidth = max(20, layer.width + value.translation.width)
                                        let newHeight = max(20, layer.height + value.translation.height)
                                        
                                        // Si c'est un carré parfait (largeur == hauteur), on applique la même valeur
                                        if layer.width == layer.height {
                                            layer.width = newWidth
                                            layer.height = newWidth
                                        } else {
                                            layer.width = newWidth
                                            layer.height = newHeight
                                        }
                                    }
                            )
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture { isEditing.toggle() }
                
            case .circle(let color, let isFilled, let strokeThickness):
                ZStack(alignment: .bottomTrailing) {
                    if isFilled {
                        Ellipse()
                            .foregroundStyle(color.asColor)
                            .frame(width: layer.width, height: layer.height)
                            .opacity(layer.opacity ?? 1)
                    } else {
                        Ellipse()
                            .stroke(color.asColor, lineWidth: strokeThickness)
                            .frame(width: layer.width, height: layer.height)
                            .opacity(layer.opacity ?? 1)
                    }
                    
                    if isEditing {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 20, height: 20)
                            .offset(x: 6, y: 6)
                            .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        let newWidth = max(20, layer.width + value.translation.width)
                                        let newHeight = max(20, layer.height + value.translation.height)
                                        
                                        if layer.width == layer.height {
                                            layer.width = newWidth
                                            layer.height = newWidth
                                        } else {
                                            layer.width = newWidth
                                            layer.height = newHeight
                                        }
                                    }
                            )
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture { isEditing.toggle() }
                
            case .text(let textContent, let color, let size, let fontName):
                if isEditing {
                    // 1. Dynamically create a runtime Binding for the text field input stream mapping
                    let textBinding = Binding(
                        get: { textContent },
                        set: { layer.content = .text(text: $0, color: color, size: size, font: fontName) }
                    )
                    
                    // 2. Render input TextField directly on top of the graphics layer coordinates
                    TextField("", text: textBinding, onCommit: {
                        isEditing = false // Commit edits on carriage return hit action
                    })
                    .textFieldStyle(.plain) // Remove native boundaries borders to keep a clean look
                    .font(.custom(fontName, size: size))
                    .foregroundStyle(color.asColor)
                    .frame(width: layer.width)
                    
                } else {
                    // 3. Static read-only rendering block viewport state
                    Text(textContent)
                        .font(.custom(fontName, size: size))
                        .foregroundStyle(color.asColor)
                        .opacity(layer.opacity ?? 1)
                        .onTapGesture(count: 2) {
                            isEditing = true
                        }
                }
                
            case .image(let data, _):
                if let nsImage = NSImage(data: data) {
                    let cLeft = layer.cropLeft ?? 0
                    let cRight = layer.cropRight ?? 0
                    let cTop = layer.cropTop ?? 0
                    let cBottom = layer.cropBottom ?? 0
                    
                    Image(nsImage: nsImage)
                        .resizable()
                        .scaledToFill()
                        .offset(x: (cRight - cLeft) / 2, y: (cBottom - cTop) / 2)
                        .frame(width: layer.width, height: layer.height)
                        .clipped()
                        .opacity(layer.opacity ?? 1)
                }
                
            case .arrow(let startPoint, let endPoint, let color, let style, let thickness):
                ZStack {
                    ArrowShape(
                        start: CGPoint(x: startPoint.x + dragOffset.width, y: startPoint.y + dragOffset.height),
                        end:   CGPoint(x: endPoint.x   + dragOffset.width, y: endPoint.y   + dragOffset.height),
                        arrowStyle: style,
                        thickness: thickness
                    )
                    .stroke(color.asColor, style: StrokeStyle(lineWidth: thickness, lineCap: .round, lineJoin: .round))
                    .contentShape(StrokeShape(path: ArrowShape(start: startPoint, end: endPoint, arrowStyle: style, thickness: thickness).path(in: .zero), lineWidth: thickness + 15))
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                dragOffset = value.translation
                            }
                            .onEnded { value in
                                let finalStart = CGPoint(x: startPoint.x + value.translation.width, y: startPoint.y + value.translation.height)
                                let finalEnd   = CGPoint(x: endPoint.x   + value.translation.width, y: endPoint.y   + value.translation.height)
                                layer.content = .arrow(start: finalStart, end: finalEnd, color: color, style: style, thickness: thickness)
                                dragOffset = .zero
                            }
                    )
                    .onTapGesture { isEditing.toggle() }
    
                    if isEditing {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 12, height: 12)
                            .position(CGPoint(x: startPoint.x + dragOffset.width, y: startPoint.y + dragOffset.height))
                            .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        let shiftHeld = NSEvent.modifierFlags.contains(.shift)
                                        let newStart = shiftHeld ? snapToRemarkableAngle(from: endPoint, to: value.location) : value.location
                                        layer.content = .arrow(start: newStart, end: endPoint, color: color, style: style, thickness: thickness)
                                    }
                            )
                        
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 12, height: 12)
                            .position(CGPoint(x: endPoint.x + dragOffset.width, y: endPoint.y + dragOffset.height))
                            .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        let shiftHeld = NSEvent.modifierFlags.contains(.shift)
                                        let newEnd = shiftHeld ? snapToRemarkableAngle(from: startPoint, to: value.location) : value.location
                                        layer.content = .arrow(start: startPoint, end: newEnd, color: color, style: style, thickness: thickness)
                                    }
                            )
                    }
                }
                
            case .transparent:
                Canvas { context, size in
                    let squareSize: CGFloat = 10
                    for x in stride(from: 0, to: size.width, by: squareSize) {
                        for y in stride(from: 0, to: size.height, by: squareSize) {
                            let isGray = (Int(x / squareSize) + Int(y / squareSize)) % 2 == 0
                            let rectFrame = CGRect(x: x, y: y, width: squareSize, height: squareSize)
                            context.fill(Path(rectFrame), with: .color(isGray ? Color(nsColor: .lightGray).opacity(0.3) : .white))
                        }
                    }
                }
                .allowsHitTesting(false)
                
            case .drawing(let lines, let color, let thickness):
                Canvas { context, size in
                    for line in lines {
                        var path = Path()
                        guard let firstPoint = line.first else { continue }
                        path.move(to: firstPoint)
                        for point in line.dropFirst() { path.addLine(to: point) }
                        context.stroke(path, with: .color(color.asColor), style: StrokeStyle(lineWidth: thickness, lineCap: .round, lineJoin: .round))
                    }
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            var updatedLines = lines
                            if value.translation == .zero {
                                if let undoManager = undoManager {
                                    let previousConfiguration = lines
                                    undoManager.registerUndo(withTarget: undoManager) { _ in
                                        layer.content = .drawing(lines: previousConfiguration, color: color, thickness: thickness)
                                    }
                                }
                                updatedLines.append([value.location])
                            } else {
                                if let lastLineIndex = updatedLines.indices.last {
                                    updatedLines[lastLineIndex].append(value.location)
                                }
                            }
                            layer.content = .drawing(lines: updatedLines, color: color, thickness: thickness)
                        }
                )
            }
        }
    }
    
    // --- APP SECURITY DATA SCOPE HANDLING METHODS ---
    private func loadImageFromBookmark(bookmarkData: Data) -> NSImage? {
        var isStale = false
        guard let url = try? URL(resolvingBookmarkData: bookmarkData, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale) else {
            return nil
        }
        
        let hasAccess = url.startAccessingSecurityScopedResource()
        let imageResult = NSImage(contentsOf: url)
        if hasAccess { url.stopAccessingSecurityScopedResource() }
        
        return imageResult
    }
    
    private func snapToRemarkableAngle(from anchor: CGPoint, to free: CGPoint) -> CGPoint {
        let dx = free.x - anchor.x
        let dy = free.y - anchor.y
        let length = sqrt(dx * dx + dy * dy)
        guard length > 0 else { return free }
        
        let angleRad = atan2(dy, dx)
        let angleDeg = angleRad * 180 / .pi
        
        // Angles remarquables tous les 45°
        let step = 45.0
        let snappedDeg = (angleDeg / step).rounded() * step
        let snappedRad = snappedDeg * .pi / 180
        
        return CGPoint(
            x: anchor.x + length * cos(snappedRad),
            y: anchor.y + length * sin(snappedRad)
        )
    }
}

struct StrokeShape: Shape {
    var path: Path
    var lineWidth: CGFloat

    func path(in rect: CGRect) -> Path {
        return path.cgPath.copy(strokingWithWidth: lineWidth, lineCap: .round, lineJoin: .round, miterLimit: 1).toPath()
    }
}

extension CGPath {
    func toPath() -> Path { Path(self) }
}
