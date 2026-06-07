//
//  LayerOptionsView.swift
//  ImageAnnotator
//
//  Created by Mathieu CUVELIER on 07/06/2026.
//

import SwiftUI

struct LayerOptionsView: View {
    @Binding var layer: Layer
    @Binding var layers: [Layer] // Receives the global stack to read canvas boundaries constraints
    @Environment(\.dismiss) var dismiss
    @Environment(\.undoManager) var undoManager
    let initialConfiguration: [Layer]
    
    let availableFonts = [
        "Helvetica", "Arial", "Courier New", "Times New Roman",
        "Avenir Next", "American Typewriter", "Marker Felt"
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Options du calque : \(layer.name)")
                .font(.title2)
                .bold()
            
            // Dynamically compute the maximum bounding constraints for the control sliders
            let maxProjectWidth = layers.first?.width ?? 800
            let maxProjectHeight = layers.first?.height ?? 600
            
            // --- SPECIFIC EDITOR VIEWPORTS SECTIONS DEPENDING ON CONTENT TYPE ---
            switch layer.content {
            
            case .text(let textContent, let color, let size, let fontName):
                let fontBinding = Binding(
                    get: { fontName },
                    set: {
                        layer.content = .text(text: textContent, color: color, size: size, font: $0)
                    }
                )
                
                let textColorBinding = Binding<Color>(
                    get: { color.asColor },
                    set: {
                        layer.content = .text(text: textContent, color: CodableColor($0), size: size, font: fontName)
                    }
                )
                
                Section(header: Text("Style du Texte").font(.headline)) {
                    Picker("Police d'écriture :", selection: fontBinding) {
                        ForEach(availableFonts, id: \.self) { font in
                            Text(font).font(.custom(font, size: 14))
                        }
                    }
                    
                    HStack {
                        Text("Taille de la police : \(Int(size))")
                        Slider(
                            value: Binding(
                                get: { size },
                                set: { layer.content = .text(text: textContent, color: color, size: $0, font: fontName) }
                            ),
                            in: 10...100
                        )
                    }
                    
                    HStack {
                        Text("Couleur de la police :")
                        ColorPicker("", selection: textColorBinding)
                    }
                }
                
            case .rectangle(let color):
                let ratioLockedBinding = Binding<Bool>(
                    get: { layer.width == layer.height },
                    set: { makeSquare in
                        if makeSquare {
                            layer.height = layer.width
                        } else {
                            layer.height = layer.width - 1
                        }
                    }
                )
                
                Section(header: Text("Dimensions du Rectangle").font(.headline)) {
                    Toggle("Carré parfait (Bloquer le ratio)", isOn: ratioLockedBinding)
                        .padding(.bottom, 5)
                    
                    HStack {
                        Text("Largeur : \(Int(layer.width))px")
                        Slider(
                            value: Binding(
                                get: { layer.width },
                                set: { newWidth in
                                    let wasSquare = layer.width == layer.height
                                    layer.width = newWidth
                                    if wasSquare { layer.height = newWidth }
                                }
                            ),
                            in: 10...maxProjectWidth
                        )
                    }
                    
                    if layer.width != layer.height {
                        HStack {
                            Text("Hauteur : \(Int(layer.height))px")
                            Slider(
                                value: $layer.height,
                                in: 10...maxProjectHeight
                            )
                        }
                    } else {
                        Text("Hauteur automatique : \(Int(layer.height))px")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                
                let rectColorBinding = Binding<Color>(
                    get: { color.asColor },
                    set: {
                        layer.content = .rectangle(color: CodableColor($0))
                    }
                )
                
                Section(header: Text("Style").font(.headline)) {
                    ColorPicker("Couleur du rectangle :", selection: rectColorBinding)
                }

            case .circle(let color):
                let ratioLockedBinding = Binding<Bool>(
                    get: { layer.width == layer.height },
                    set: { makePerfectCircle in
                        if makePerfectCircle {
                            layer.height = layer.width
                        } else {
                            layer.height = layer.width - 1
                        }
                    }
                )
                
                Section(header: Text("Dimensions du Cercle").font(.headline)) {
                    Toggle("Cercle parfait (Bloquer le ratio)", isOn: ratioLockedBinding)
                        .padding(.bottom, 5)
                    
                    HStack {
                        Text("Largeur : \(Int(layer.width))px")
                        Slider(
                            value: Binding(
                                get: { layer.width },
                                set: { newWidth in
                                    let wasPerfectCircle = layer.width == layer.height
                                    layer.width = newWidth
                                    if wasPerfectCircle { layer.height = newWidth }
                                }
                            ),
                            in: 10...maxProjectWidth
                        )
                    }
                    
                    if layer.width != layer.height {
                        HStack {
                            Text("Hauteur : \(Int(layer.height))px")
                            Slider(
                                value: $layer.height,
                                in: 10...maxProjectHeight
                            )
                        }
                    } else {
                        Text("Hauteur automatique : \(Int(layer.height))px")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                
                let circleColorBinding = Binding<Color>(
                    get: { color.asColor },
                    set: {
                        layer.content = .circle(color: CodableColor($0))
                    }
                )
                
                Section(header: Text("Style").font(.headline)) {
                    ColorPicker("Couleur du cercle :", selection: circleColorBinding)
                }
                
            case .arrow(let startPoint, let endPoint, let color, let arrowStyle, let thickness):
                let arrowStyleBinding = Binding(
                    get: { arrowStyle },
                    set: {
                        layer.content = .arrow(start: startPoint, end: endPoint, color: color, style: $0, thickness: thickness)
                    }
                )
                
                let arrowColorBinding = Binding<Color>(
                    get: { color.asColor },
                    set: {
                        layer.content = .arrow(start: startPoint, end: endPoint, color: CodableColor($0), style: arrowStyle, thickness: thickness)
                    }
                )

                Section(header: Text("Style de la Flèche").font(.headline)) {
                    ColorPicker("Couleur de la ligne :", selection: arrowColorBinding)
                    
                    HStack {
                        Text("Épaisseur : \(Int(thickness))px")
                        Slider(
                            value: Binding(
                                get: { thickness },
                                set: { layer.content = .arrow(start: startPoint, end: endPoint, color: color, style: arrowStyle, thickness: $0) }
                            ),
                            in: 2...20
                        )
                    }
                    
                    Picker("Type de flèche :", selection: arrowStyleBinding) {
                        ForEach(ArrowStyle.allCases) { style in
                            Text(style.rawValue).tag(style)
                        }
                    }
                }
                
            case .image(_, let originalRatio):
                Section(header: Text("Taille de l'image (Ratio conservé)").font(.headline)) {
                    HStack {
                        Text("Largeur : \(Int(layer.width))px")
                        Slider(
                            value: Binding(
                                get: { layer.width },
                                set: { newWidth in
                                    let clampedWidth = min(newWidth, maxProjectWidth)
                                    layer.width = clampedWidth
                                    layer.height = clampedWidth / originalRatio
                                }
                            ),
                            in: 50...maxProjectWidth
                        )
                    }
                    HStack {
                        Text("Hauteur automatique : \(Int(layer.height))px")
                            .foregroundColor(.gray)
                    }
                }
                
                Section(header: Text("Recadrer les 4 côtés").font(.headline)) {
                    // --- LEFT CROP ---
                    HStack {
                        Text("Rogner Gauche :")
                        Slider(
                            value: Binding(
                                get: { layer.cropLeft ?? 0 },
                                set: { newCropValue in
                                    let currentCrop = layer.cropLeft ?? 0
                                    let delta = newCropValue - currentCrop
                                    if layer.width - delta > 10 {
                                        layer.cropLeft = newCropValue
                                        layer.width -= delta
                                        layer.x += delta / 2
                                    }
                                }
                            ),
                            in: 0...400
                        )
                    }
                    
                    // --- RIGHT CROP ---
                    HStack {
                        Text("Rogner Droit :")
                        Slider(
                            value: Binding(
                                get: { layer.cropRight ?? 0 },
                                set: { newCropValue in
                                    let currentCrop = layer.cropRight ?? 0
                                    let delta = newCropValue - currentCrop
                                    if layer.width - delta > 10 {
                                        layer.cropRight = newCropValue
                                        layer.width -= delta
                                        layer.x -= delta / 2
                                    }
                                }
                            ),
                            in: 0...400
                        )
                    }
                    
                    // --- TOP CROP ---
                    HStack {
                        Text("Rogner Haut :")
                        Slider(
                            value: Binding(
                                get: { layer.cropTop ?? 0 },
                                set: { newCropValue in
                                    let currentCrop = layer.cropTop ?? 0
                                    let delta = newCropValue - currentCrop
                                    if layer.height - delta > 10 {
                                        layer.cropTop = newCropValue
                                        layer.height -= delta
                                        layer.y += delta / 2
                                    }
                                }
                            ),
                            in: 0...400
                        )
                    }
                    
                    // --- BOTTOM CROP ---
                    HStack {
                        Text("Rogner Bas :")
                        Slider(
                            value: Binding(
                                get: { layer.cropBottom ?? 0 },
                                set: { newCropValue in
                                    let currentCrop = layer.cropBottom ?? 0
                                    let delta = newCropValue - currentCrop
                                    if layer.height - delta > 10 {
                                        layer.cropBottom = newCropValue
                                        layer.height -= delta
                                        layer.y -= delta / 2
                                    }
                                }
                            ),
                            in: 0...400
                        )
                    }
                }
                
            case .drawing(let lines, let color, let thickness):
                let drawingColorBinding = Binding<Color>(
                    get: { color.asColor },
                    set: {
                        layer.content = .drawing(lines: lines, color: CodableColor($0), thickness: thickness)
                    }
                )

                Section(header: Text("Style du Tracé à main levée").font(.headline)) {
                    HStack {
                        Text("Épaisseur du trait : \(Int(thickness))px")
                        Slider(
                            value: Binding(
                                get: { thickness },
                                set: { layer.content = .drawing(lines: lines, color: color, thickness: $0) }
                            ),
                            in: 1...30
                        )
                    }
                    ColorPicker("Couleur du pinceau :", selection: drawingColorBinding)
                }
                
            default:
                Text("Aucune option de style avancée pour ce type de calque.")
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            // Dismiss Button Trigger
            Button("Terminé") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding()
        .frame(width: 450, height: 450)
    }
}
