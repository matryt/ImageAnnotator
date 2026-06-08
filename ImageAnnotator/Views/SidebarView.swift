//
//  SidebarView.swift
//  ImageAnnotator
//
//  Created by Mathieu CUVELIER on 07/06/2026.
//

import SwiftUI

struct SidebarView: View {
    @Binding var layers: [Layer]
    @Binding var selectedIndex: Int?
    @Environment(\.undoManager) var undoManager
    
    @State private var showOptionsSheet = false
    @State private var preSheetConfiguration: [Layer] = [] // Keeps a backup configuration of the source state before sheet changes
    
    var body: some View {
        VStack(spacing: 15) {
            Text("Outils & Calques")
                .font(.headline)
                .padding(.top)
            
            // --- CREATION TOOLS BUTTONS ---
            VStack {
                HStack {
                    Button(action: {
                        let newRectangle = Layer(name: "Rectangle \(layers.count + 1)", x: 200, y: 200, width: 150, height: 150, content: .rectangle(color: CodableColor(.blue.opacity(0.5)), isFilled: true, strokeThickness: 1))
                        registerGlobalStateForUndo()
                        layers.append(newRectangle)
                    }) {
                        Image(systemName: "square.dashed")
                        Text("+ Rectangle")
                    }
                    
                    Button(action: {
                        let newText = Layer(name: "Texte \(layers.count + 1)", x: 180, y: 180, width: 200, height: 50, content: .text(text: "Nouveau Texte", color: CodableColor(.black), size: 20, font: "Helvetica"))
                        registerGlobalStateForUndo()
                        layers.append(newText)
                    }) {
                        Image(systemName: "text.alignleft")
                        Text("+ Texte")
                    }
                }
                .padding(.horizontal)
                .buttonStyle(.bordered)
                
                HStack {
                    Button(action: {
                        let newArrow = Layer(
                            name: "Flèche \(layers.count + 1)",
                            x: 0, y: 0, width: 0, height: 0,
                            content: .arrow(start: CGPoint(x: 100, y: 100), end: CGPoint(x: 250, y: 100), color: CodableColor(.gray), style: .end, thickness: 10)
                        )
                        registerGlobalStateForUndo()
                        layers.append(newArrow)
                    }) {
                        Image(systemName: "arrow.up.forward")
                        Text("+ Flèche")
                    }
                    
                    Button(action: {
                        let newCircle = Layer(
                            name: "Cercle \(layers.count + 1)",
                            x: 150, y: 150, width: 100, height: 100,
                            content: .circle(color: CodableColor(.blue), isFilled: true, strokeThickness: 1)
                        )
                        registerGlobalStateForUndo()
                        layers.append(newCircle)
                    }) {
                        Image(systemName: "circle")
                        Text("+ Cercle")
                    }
                }
                
                HStack {
                    Button(action: {
                        let maxWidth = layers.first?.width ?? 800
                        let maxHeight = layers.first?.height ?? 600
                        
                        let newDrawing = Layer(
                            name: "Dessin \(layers.count + 1)",
                            x: maxWidth / 2,
                            y: maxHeight / 2,
                            width: maxWidth,
                            height: maxHeight,
                            content: .drawing(lines: [], color: CodableColor(.red), thickness: 4)
                        )
                        registerGlobalStateForUndo()
                        layers.append(newDrawing)
                    }) {
                        Image(systemName: "scribble")
                        Text("+ Dessin libre")
                    }
                }
                .padding(.horizontal)
                .buttonStyle(.bordered)
            }
            
            Divider()
            
            // --- LAYERS COLLECTION SIDEBAR LIST ---
            List {
                ForEach(layers.indices.reversed(), id: \.self) { index in
                    layerRow(for: index)
                }
            }
            .listStyle(.sidebar)
        }
        .sheet(isPresented: $showOptionsSheet) {
            if let index = selectedIndex, index < layers.count {
                LayerOptionsView(
                    layer: $layers[index],
                    layers: $layers,
                    initialConfiguration: preSheetConfiguration
                )
                .onDisappear {
                    if let currentData = try? JSONEncoder().encode(layers),
                       let initialData = try? JSONEncoder().encode(preSheetConfiguration),
                       currentData != initialData {
                        if let undoManager = undoManager {
                            let historyCopy = preSheetConfiguration
                            
                            // Attach the Undo action target context to NSApp to avoid system automatic cleanup on sheet dismissal
                            undoManager.registerUndo(withTarget: NSApp) { _ in
                                self.layers = historyCopy
                            }
                        }
                    }
                }
            }
        }
        .frame(width: 250)
    }
    
    // --- MODULAR EXTRACTED SUBVIEW CELLS FOR LIGHTWEIGHT TYPE-CHECKING RENDERS ---
    private func layerRow(for index: Int) -> some View {
        HStack {
            Text(layers[index].name)
            Spacer()
            
            Button(action: { moveLayerUp(at: index) }) {
                Image(systemName: "chevron.up")
            }
            .buttonStyle(.borderless)
            .disabled(index == layers.count - 1)
            
            Button(action: { moveLayerDown(at: index) }) {
                Image(systemName: "chevron.down")
            }
            .buttonStyle(.borderless)
            .disabled(index == 0)
            
            Button(action: { deleteLayer(at: index) }) {
                Image(systemName: "xmark.circle.fill")
            }
            .buttonStyle(.borderless)
            .foregroundColor(.red)
            .keyboardShortcut(KeyEquivalent.delete)
            
            Button(action: {
                selectedIndex = index
                if let data = try? JSONEncoder().encode(layers) {
                    self.preSheetConfiguration = (try? JSONDecoder().decode([Layer].self, from: data)) ?? []
                }
                showOptionsSheet = true
            }) {
                Image(systemName: "gearshape.fill")
            }
            .buttonStyle(.borderless)
            
            Button(action: {
                layers[index].isVisible = !(layers[index].isVisible ?? true)
            }) {
                Image(systemName: (layers[index].isVisible ?? true) ? "eye" : "eye.slash")
                    .foregroundColor((layers[index].isVisible ?? true) ? .blue : .gray)
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 4)
        .background(selectedIndex == index ? Color.blue.opacity(0.2) : Color.clear)
        .onTapGesture {
            selectedIndex = index
        }
    }
    
    // --- LOCAL ACTIONS AND UNDO REGISTRATION CORE HANDLERS ---
    private func registerGlobalStateForUndo() {
        if let undoManager = undoManager {
            let currentState = layers
            undoManager.registerUndo(withTarget: NSApp) { _ in
                self.layers = currentState
            }
        }
    }
    
    private func moveLayerUp(at index: Int) {
        if index < layers.count - 1 {
            registerGlobalStateForUndo()
            layers.swapAt(index, index + 1)
            if selectedIndex == index { selectedIndex = index + 1 }
        }
    }
    
    private func moveLayerDown(at index: Int) {
        if index > 0 {
            registerGlobalStateForUndo()
            layers.swapAt(index, index - 1)
            if selectedIndex == index { selectedIndex = index - 1 }
        }
    }
    
    private func deleteLayer(at index: Int) {
        registerGlobalStateForUndo()
        layers.remove(at: index)
        selectedIndex = nil
    }
}
