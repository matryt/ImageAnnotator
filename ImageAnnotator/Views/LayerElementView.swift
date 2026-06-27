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
    
    // Repère d'origine pur : la forme occupe tout son espace, c'est le masque qui la tranchera
    private var nativePathRect: CGRect {
        return CGRect(x: 0, y: 0, width: layer.width, height: layer.height)
    }
    
    var body: some View {
        ZStack {
            switch layer.content {
            case .rectangle(let color, let isFilled, let strokeThickness):
                ZStack(alignment: .bottomTrailing) {
                    if isFilled {
                        Path { path in
                            path.addRect(nativePathRect)
                        }
                        .fill(color.asColor)
                        .opacity(layer.opacity ?? 1)
                    } else {
                        Path { path in
                            path.addRect(nativePathRect)
                        }
                        .stroke(color.asColor, lineWidth: strokeThickness)
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
                                        let heightShift = layer.width == layer.height ? newWidth : max(20, layer.height + value.translation.height)
                                        layer.width = newWidth
                                        layer.height = heightShift
                                    }
                            )
                    }
                }
                .frame(width: layer.width, height: layer.height)
                .contentShape(Rectangle())
                .onTapGesture { isEditing.toggle() }
                
            case .circle(let color, let isFilled, let strokeThickness):
                ZStack(alignment: .bottomTrailing) {
                    if isFilled {
                        Path { path in
                            path.addEllipse(in: nativePathRect)
                        }
                        .fill(color.asColor)
                        .opacity(layer.opacity ?? 1)
                    } else {
                        Path { path in
                            path.addEllipse(in: nativePathRect)
                        }
                        .stroke(color.asColor, lineWidth: strokeThickness)
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
                                        let heightShift = layer.width == layer.height ? newWidth : max(20, layer.height + value.translation.height)
                                        layer.width = newWidth
                                        layer.height = heightShift
                                    }
                            )
                    }
                }
                .frame(width: layer.width, height: layer.height)
                .contentShape(Rectangle())
                .onTapGesture { isEditing.toggle() }
                
            case .text(let textContent, let color, let size, let fontName):
                if isEditing {
                    let textBinding = Binding(
                        get: { textContent },
                        set: { layer.content = .text(text: $0, color: color, size: size, font: fontName) }
                    )
                    TextField("", text: textBinding, onCommit: { isEditing = false })
                        .textFieldStyle(.plain)
                        .font(.custom(fontName, size: size))
                        .foregroundStyle(color.asColor)
                        .frame(width: layer.width)
                } else {
                    Text(textContent)
                        .font(.custom(fontName, size: size))
                        .foregroundStyle(color.asColor)
                        .opacity(layer.opacity ?? 1)
                        .onTapGesture(count: 2) { isEditing = true }
                }
                
            case .image(let data, _):
                if let nsImage = NSImage(data: data) {
                    // L'image s'affiche à 100% de son espace natif stable.
                    // C'est l'encapsulation de DrawingCanvasView qui la rogne !
                    Image(nsImage: nsImage)
                        .resizable()
                        .scaledToFill()
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
                            .onChanged { value in dragOffset = value.translation }
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
    
    private func loadImageFromBookmark(bookmarkData: Data) -> NSImage? {
        var isStale = false
        guard let url = try? URL(resolvingBookmarkData: bookmarkData, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale) else { return nil }
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
        let step = 45.0
        let snappedDeg = (angleDeg / step).rounded() * step
        let snappedRad = snappedDeg * .pi / 180
        return CGPoint(x: anchor.x + length * cos(snappedRad), y: anchor.y + length * sin(snappedRad))
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
