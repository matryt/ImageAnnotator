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
    
    @Environment(\.undoManager) var undoManager
    
    var body: some View {
        ZStack {
            switch layer.content {
                
            case .rectangle(let color):
                Rectangle()
                    .foregroundStyle(color.asColor)
                    .frame(width: layer.width, height: layer.height)
                    .opacity(layer.opacity ?? 1)
                    
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
                        // Capture double-tap gesture mapping hook sequence to trigger inline edit mode
                        .onTapGesture(count: 2) {
                            isEditing = true
                        }
                }
                
            case .image(let bookmarkData, _):
                if let nsImage = loadImageFromBookmark(bookmarkData: bookmarkData) {
                    let cLeft = layer.cropLeft ?? 0
                    let cRight = layer.cropRight ?? 0
                    let cTop = layer.cropTop ?? 0
                    let cBottom = layer.cropBottom ?? 0
                    
                    Image(nsImage: nsImage)
                        .resizable()
                        .scaledToFill()
                        // Offset internal texture mapping coordinates bounds context
                        .offset(x: (cRight - cLeft) / 2, y: (cBottom - cTop) / 2)
                        // Apply layout frames properties computed safely from the layer properties
                        .frame(width: layer.width, height: layer.height)
                        .clipped()
                        .opacity(layer.opacity ?? 1)
                }
                
            case .arrow(let startPoint, let endPoint, let color, let style, let thickness):
                ZStack {
                    // 1. Render vector arrow lines path
                    ArrowShape(start: startPoint, end: endPoint, arrowStyle: style, thickness: thickness)
                        .stroke(color.asColor, style: StrokeStyle(lineWidth: thickness, lineCap: .round, lineJoin: .round))
                        // Clickable surface area extension hack for thinner path gesture tracking captures
                        .contentShape(Rectangle())
                        .onTapGesture {
                            isEditing.toggle() // Toggles vector anchor transform handle visibility pointers
                        }
                    
                    // 2. Control handles displayed depending on local view component state bindings
                    if isEditing {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 12, height: 12)
                            .position(startPoint)
                            .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        layer.content = .arrow(start: value.location, end: endPoint, color: color, style: style, thickness: thickness)
                                    }
                            )
                        
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 12, height: 12)
                            .position(endPoint)
                            .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        layer.content = .arrow(start: startPoint, end: value.location, color: color, style: style, thickness: thickness)
                                    }
                            )
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
            case .transparent:
                Canvas { context, size in
                    let squareSize: CGFloat = 10
                    for x in stride(from: 0, to: size.width, by: squareSize) {
                        for y in stride(from: 0, to: size.height, by: squareSize) {
                            // Alternating pattern background fill logic computation loops
                            let isGray = (Int(x / squareSize) + Int(y / squareSize)) % 2 == 0
                            let rectFrame = CGRect(x: x, y: y, width: squareSize, height: squareSize)
                            context.fill(Path(rectFrame), with: .color(isGray ? Color(nsColor: .lightGray).opacity(0.3) : .white))
                        }
                    }
                }
                
            case .circle(let color):
                Ellipse() // Fallback canvas for both uniform regular circles and free anamorphic ovals profiles
                    .foregroundStyle(color.asColor)
                    .frame(width: layer.width, height: layer.height)
                    .opacity(layer.opacity ?? 1)
            
            case .drawing(let lines, let color, let thickness):
                Canvas { context, size in
                    // Render each user pointer path stroke individually
                    for line in lines {
                        var path = Path()
                        guard let firstPoint = line.first else { continue }
                        path.move(to: firstPoint)
                        
                        for point in line.dropFirst() {
                            path.addLine(to: point)
                        }
                        
                        context.stroke(path, with: .color(color.asColor), style: StrokeStyle(lineWidth: thickness, lineCap: .round, lineJoin: .round))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            var updatedLines = lines
                            
                            if value.translation == .zero {
                                if let undoManager = undoManager {
                                    // Deep copy configuration snapshot backup for flawless undo tracking
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
}
