//
//  ContentView.swift
//  ImageAnnotator
//
//  Created by Mathieu CUVELIER on 07/06/2026.
//

import SwiftUI
import UniformTypeIdentifiers
import Combine

struct ContentView: View {
    @StateObject private var manager = ProjectManager()
    @Environment(\.undoManager) var undoManager
    
    @State private var startX: CGFloat = 0
    @State private var startY: CGFloat = 0
    
    @State private var selectedLayerIndex: Int? = nil
    
    @State private var canvasWidth: Double = 800
    @State private var canvasHeight: Double = 600
    @State private var backgroundColor: Color = .white
    @State private var isTransparentBackground = false
    @State private var isProjectInitialized: Bool = false
    
    var body: some View {
        if !isProjectInitialized {
            // --- WELCOME & SETUP INITIAL VIEW ---
            VStack(spacing: 20) {
                Text("Créer un nouveau canevas")
                    .font(.title)
                    .bold()
                
                Form {
                    TextField("Largeur (px) :", value: $canvasWidth, format: .number)
                    TextField("Hauteur (px) :", value: $canvasHeight, format: .number)
                    
                    Toggle("Fond transparent", isOn: $isTransparentBackground)
                    
                    if !isTransparentBackground {
                        ColorPicker("Couleur de fond :", selection: $backgroundColor)
                    }
                }
                .frame(width: 300)
                
                Button("Créer le canevas") {
                    let backgroundLayer: Layer
                    if isTransparentBackground {
                        backgroundLayer = Layer(name: "Arrière-plan", x: CGFloat(canvasWidth / 2), y: CGFloat(canvasHeight / 2), width: CGFloat(canvasWidth), height: CGFloat(canvasHeight), content: .transparent(val: true))
                    } else {
                        backgroundLayer = Layer(
                            name: "Arrière-plan",
                            x: CGFloat(canvasWidth / 2),
                            y: CGFloat(canvasHeight / 2),
                            width: CGFloat(canvasWidth),
                            height: CGFloat(canvasHeight),
                            content: .rectangle(color: CodableColor(backgroundColor))
                        )
                    }
                    
                    manager.registerStateForUndo(undoManager: undoManager, previousState: manager.layers)
                    manager.layers.append(backgroundLayer)
                    isProjectInitialized = true
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                
                Button("Ouvrir un projet existant") {
                    loadProject()
                }
                .buttonStyle(.borderless)
                .padding(.top, 5)
                
                Button("Ouvrir une image existante") {
                    openImageDirectly()
                }
                .buttonStyle(.borderless)
                .padding(.top, 5)
            }
            .frame(minWidth: 500, minHeight: 400)
            
        } else {
            // --- MAIN EDITOR WORKSPACE VIEW ---
            HStack(spacing: 0) {
                SidebarView(layers: $manager.layers, selectedIndex: $selectedLayerIndex)
                
                Divider()
                
                GeometryReader { geometry in
                    ZStack {
                        Color(nsColor: .windowBackgroundColor)
                        
                        // Render extracted modular canvas view
                        DrawingCanvasView(
                            manager: manager,
                            undoManager: undoManager,
                            startX: $startX,
                            startY: $startY,
                            canvasWidth: canvasWidth,
                            canvasHeight: canvasHeight
                        )
                        .shadow(radius: 8)
                    }
                }
            }
            // Application system notification events listeners
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("DeclencherImport"))) { _ in
                importImage()
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("DeclencherExport"))) { _ in
                exportImage()
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("OuvrirProjet"))) { _ in
                loadProject()
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("EnregistrerProjet"))) { _ in
                saveProject()
            }
            // Core First Responder Menu Actions Hooks
            .onCommand(#selector(NSText.copy(_:))) {
                copySelectedLayer()
            }
            .onCommand(#selector(NSText.paste(_:))) {
                pasteLayer()
            }
            .onCommand(#selector(NSText.cut(_:))) {
                cutSelectedLayer()
            }
        }
    }

    // --- ASYNC & FILE MANAGEMENT LOGIC METHOD EXTRACTIONS ---
    
    private func importImage() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.image]
        
        if panel.runModal() == .OK, let url = panel.url {
            if let bookmarkData = try? url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil) {
                
                var initialWidth: CGFloat = 300
                var initialHeight: CGFloat = 200
                var ratio: CGFloat = 1.5
                
                if let nsImage = NSImage(contentsOf: url) {
                    initialWidth = nsImage.size.width
                    initialHeight = nsImage.size.height
                    if initialHeight > 0 {
                        ratio = initialWidth / initialHeight
                    }
                }
                
                let currentProjectWidth = manager.layers.first?.width ?? CGFloat(canvasWidth)
                let maxCanvasLimit = currentProjectWidth * 0.7
                
                if initialWidth > maxCanvasLimit {
                    initialWidth = maxCanvasLimit
                    initialHeight = initialWidth / ratio
                }
                
                let centerX = (manager.layers.first?.width ?? CGFloat(canvasWidth)) / 2
                let centerY = (manager.layers.first?.height ?? CGFloat(canvasHeight)) / 2
                
                manager.registerStateForUndo(undoManager: undoManager, previousState: manager.layers)
                manager.layers.append(Layer(
                    name: url.lastPathComponent,
                    x: centerX,
                    y: centerY,
                    width: initialWidth,
                    height: initialHeight,
                    content: .image(data: bookmarkData, ratio: ratio)
                ))
            }
        }
    }
    
    @MainActor
    private func exportImage() {
        // Render current canvas dynamically without modifying source components
        let drawingCanvas = DrawingCanvasView(
            manager: manager,
            undoManager: undoManager,
            startX: $startX,
            startY: $startY,
            canvasWidth: canvasWidth,
            canvasHeight: canvasHeight
        )
        
        let renderer = ImageRenderer(content: drawingCanvas)
        renderer.scale = 2.0
        
        let backgroundLayerIndex = manager.layers.firstIndex(where: { $0.name == "Arrière-plan" })
        var isBackgroundTransparent = false
        
        if let index = backgroundLayerIndex {
            if case .transparent = manager.layers[index].content {
                isBackgroundTransparent = true
            }
        }
        
        let originalVisibility = backgroundLayerIndex != nil ? (manager.layers[backgroundLayerIndex!].isVisible ?? true) : true
        
        if let index = backgroundLayerIndex, isBackgroundTransparent {
            manager.layers[index].isVisible = false
        }
        
        if let nsImage = renderer.nsImage {
            if let index = backgroundLayerIndex, isBackgroundTransparent {
                manager.layers[index].isVisible = originalVisibility
            }
            let savePanel = NSSavePanel()
            savePanel.allowedContentTypes = [.png]
            savePanel.nameFieldStringValue = "mon_annotation.png"
            
            if savePanel.runModal() == .OK, let url = savePanel.url {
                if let tiffData = nsImage.tiffRepresentation,
                   let bitmapRep = NSBitmapImageRep(data: tiffData),
                   let pngData = bitmapRep.representation(using: .png, properties: [:]) {
                    try? pngData.write(to: url)
                }
            }
        } else {
            if let index = backgroundLayerIndex, isBackgroundTransparent {
                manager.layers[index].isVisible = originalVisibility
            }
        }
    }
    
    private func saveProject() {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.json]
        savePanel.nameFieldStringValue = "mon_projet.json"
        
        if savePanel.runModal() == .OK, let url = savePanel.url {
            if let data = try? JSONEncoder().encode(manager.layers) {
                try? data.write(to: url)
            }
        }
    }

    private func loadProject() {
        let openPanel = NSOpenPanel()
        openPanel.allowedContentTypes = [.json]
        openPanel.allowsMultipleSelection = false
        
        if openPanel.runModal() == .OK, let url = openPanel.url {
            if let data = try? Data(contentsOf: url),
               let loadedLayers = try? JSONDecoder().decode([Layer].self, from: data) {
                self.manager.layers = loadedLayers
                self.isProjectInitialized = true
            }
        }
    }
    
    private func openImageDirectly() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.image]
        
        if panel.runModal() == .OK, let url = panel.url {
            if let bookmarkData = try? url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil) {
                
                var initialWidth: CGFloat = 800
                var initialHeight: CGFloat = 600
                var ratio: CGFloat = 1.33
                
                if let nsImage = NSImage(contentsOf: url) {
                    initialWidth = nsImage.size.width
                    initialHeight = nsImage.size.height
                    if initialHeight > 0 {
                        ratio = initialWidth / initialHeight
                    }
                }
                
                self.canvasWidth = Double(initialWidth)
                self.canvasHeight = Double(initialHeight)
                
                let backgroundImageLayer = Layer(
                    name: "Arrière-plan",
                    x: initialWidth / 2,
                    y: initialHeight / 2,
                    width: initialWidth,
                    height: initialHeight,
                    content: .image(data: bookmarkData, ratio: ratio)
                )
                
                if let undoManager = undoManager {
                    undoManager.removeAllActions()
                }
                
                manager.layers = [backgroundImageLayer]
                self.isProjectInitialized = true
            }
        }
    }
    
    // --- EDITIONS AND REPLICATION CLIPBOARD FEATURES ---

    private func copySelectedLayer() {
        guard let index = selectedLayerIndex, manager.layers.indices.contains(index) else { return }
        
        if let data = try? JSONEncoder().encode(manager.layers[index]),
           let layerCopy = try? JSONDecoder().decode(Layer.self, from: data) {
            manager.clipboardLayer = layerCopy
        }
    }

    private func pasteLayer() {
        guard let layerToPaste = manager.clipboardLayer else { return }
        
        if let data = try? JSONEncoder().encode(layerToPaste),
           var newLayer = try? JSONDecoder().decode(Layer.self, from: data) {
            
            newLayer.x += 20
            newLayer.y += 20
            newLayer.name += " (Copie)"
            newLayer.id = UUID()
            
            if let undoManager = undoManager {
                let currentState = manager.layers
                undoManager.registerUndo(withTarget: undoManager) { _ in
                    manager.layers = currentState
                }
            }
            
            manager.layers.append(newLayer)
            selectedLayerIndex = manager.layers.count - 1
        }
    }

    private func cutSelectedLayer() {
        copySelectedLayer()
        
        guard let index = selectedLayerIndex, manager.layers.indices.contains(index) else { return }
        
        if let undoManager = undoManager {
            let currentState = manager.layers
            undoManager.registerUndo(withTarget: undoManager) { _ in
                manager.layers = currentState
            }
        }
        
        manager.layers.remove(at: index)
        selectedLayerIndex = nil
    }
}
