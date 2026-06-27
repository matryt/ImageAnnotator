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
    @StateObject private var manager = ProjectManager(canvasProject: CanvasProject(width: 800, height: 600, layers: []))
    @Environment(\.undoManager) var undoManager
    
    @State private var startX: CGFloat = 0
    @State private var startY: CGFloat = 0
    
    @State private var selectedLayerIndex: Int? = nil
    
    @State private var canvasWidth: Double = 800
    @State private var canvasHeight: Double = 600
    @State private var backgroundColor: Color = .white
    @State private var isTransparentBackground = false
    @State private var isProjectInitialized: Bool = false
    
    @State private var zoomScale: CGFloat = 1.0
    @State private var zoomOffset: CGSize = .zero // Permet de déplacer le canevas quand on est zoomé
    @State private var dragBaseOffset: CGSize = .zero
    
    // --- ETATS DE GESTION DU ROGNAGE VECTORIEL BÉZIER ---
    @State private var isCropModeActive = false
    @State private var cropSelectionRect = CGRect.zero
    @State private var cropTargetAll = true
    
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
                            content: .rectangle(color: CodableColor(backgroundColor), isFilled: true, strokeThickness: 1)
                        )
                    }
                    
                    // Initialisation propre du modèle via le manager
                    let canvasProject = CanvasProject(width: canvasWidth, height: canvasHeight, layers: [backgroundLayer])
                    manager.canvasProject = canvasProject
                    
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
                // Utilisation sécurisée du binding vers les couches du projet encapsulé
                SidebarView(
                    layers: $manager.canvasProject.layers,
                    selectedIndex: $selectedLayerIndex,
                    isCropModeActive: $isCropModeActive,
                    cropTargetAll: $cropTargetAll,
                    onValidateCrop: { validateAndExecuteCrop() },
                    onCancelCrop: { cancelCropMode() }
                )
                
                Divider()
                
                GeometryReader { geometry in
                    ZStack {
                        Color(nsColor: .windowBackgroundColor)
                        
                        DrawingCanvasView(
                            manager: manager,
                            undoManager: undoManager,
                            startX: $startX,
                            startY: $startY,
                            isCropModeActive: $isCropModeActive,
                            cropSelectionRect: $cropSelectionRect,
                            cropTargetAll: $cropTargetAll
                        )
                        .shadow(radius: 8)
                        .scaleEffect(zoomScale)
                        .offset(zoomOffset)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    if NSEvent.modifierFlags.contains(.option) {
                                        zoomOffset = CGSize(
                                            width: dragBaseOffset.width + value.translation.width,
                                            height: dragBaseOffset.height + value.translation.height
                                        )
                                    }
                                }
                                .onEnded { value in
                                    if NSEvent.modifierFlags.contains(.option) {
                                        dragBaseOffset = zoomOffset
                                    }
                                }
                        )
                    }
                    .contentShape(Rectangle())
                    .clipped()
                    .background(
                        Group {
                            if isCropModeActive {
                                Button(action: { cancelCropMode() }) {}
                                .keyboardShortcut(.escape, modifiers: [])
                                .buttonStyle(.borderless)
                            }
                        }
                    )
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
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("DeclencherCopiePressePapiers"))) { _ in
                copyImageToClipboard()
            }
            .onCommand(#selector(NSText.copy(_:))) {
                copySelectedLayer()
            }
            .onCommand(#selector(NSText.paste(_:))) {
                pasteLayer()
            }
            .onCommand(#selector(NSText.cut(_:))) {
                cutSelectedLayer()
            }
            .background(
                HostingWindowFinder { window in
                    window?.onScrollWheel = { event in
                        if event.modifierFlags.contains(.command) {
                            let delta = event.deltaY
                            let zoomFactor: CGFloat = delta > 0 ? 1.1 : 0.9
                            
                            // On applique le zoom en le bridant entre 0.5x et 5.0x pour éviter l'infini
                            let newScale = max(0.5, min(5.0, zoomScale * zoomFactor))
                            
                            withAnimation(.easeOut(duration: 0.1)) {
                                zoomScale = newScale
                                // Si on revient à 100%, on recentre le canevas automatiquement
                                if zoomScale == 1.0 { zoomOffset = .zero }
                            }
                        }
                    }
                }
            )
        }
    }

    // --- LOGIQUE METIER : DECOUPE STYLE PHOTOFILTRE ---
    
    private func cancelCropMode() {
        isCropModeActive = false
        cropSelectionRect = .zero
    }
    
    private func validateAndExecuteCrop() {
        if cropTargetAll {
            applyGlobalCanvasCrop()
        } else {
            applyLayerChirurgicalCrop()
        }
    }
    
    private func applyGlobalCanvasCrop() {
        guard cropSelectionRect.width > 10 && cropSelectionRect.height > 10 else { return }
        manager.registerStateForUndo(undoManager: undoManager, previousState: manager.getLayers())
        
        let cropBox = cropSelectionRect
        let deltaX = cropBox.minX
        let deltaY = cropBox.minY
        
        self.canvasWidth = Double(cropBox.width)
        self.canvasHeight = Double(cropBox.height)
        manager.canvasProject.width = Double(cropBox.width)
        manager.canvasProject.height = Double(cropBox.height)
        
        for index in manager.canvasProject.layers.indices {
            if manager.canvasProject.layers[index].name == "Arrière-plan" {
                manager.canvasProject.layers[index].width = cropBox.width
                manager.canvasProject.layers[index].height = cropBox.height
                manager.canvasProject.layers[index].x = cropBox.width / 2
                manager.canvasProject.layers[index].y = cropBox.height / 2
                continue
            }
            // Décale tous les calques pour s'aligner sur le nouveau coin (0,0) du projet
            manager.canvasProject.layers[index].x -= deltaX
            manager.canvasProject.layers[index].y -= deltaY
        }
        cancelCropMode()
    }
    
    private func applyLayerChirurgicalCrop() {
        guard cropSelectionRect.width > 10 && cropSelectionRect.height > 10,
              let index = selectedLayerIndex else { return }
        
        manager.registerStateForUndo(undoManager: undoManager, previousState: manager.getLayers())
        
        let selection = cropSelectionRect
        let layer = manager.canvasProject.layers[index]
        
        switch layer.content {
        case .arrow(let start, let end, let color, let style, let thickness):
            // --- CAS DE LA FLÈCHE : Recadrage chirurgical des extrémités ---
            let newStart = CGPoint(
                x: max(selection.minX, min(selection.maxX, start.x)),
                y: max(selection.minY, min(selection.maxY, start.y))
            )
            let newEnd = CGPoint(
                x: max(selection.minX, min(selection.maxX, end.x)),
                y: max(selection.minY, min(selection.maxY, end.y))
            )
            manager.canvasProject.layers[index].content = .arrow(start: newStart, end: newEnd, color: color, style: style, thickness: thickness)
            
        case .drawing(let lines, let color, let thickness):
            // --- CAS DU DESSIN LIBRE : Nettoyage et suppression des segments hors-zone ---
            var newLines: [[CGPoint]] = []
            for line in lines {
                var currentSegment: [CGPoint] = []
                for point in line {
                    // On ne garde le point que s'il est à l'intérieur de la boîte de découpe
                    if selection.contains(point) {
                        currentSegment.append(point)
                    } else {
                        if !currentSegment.isEmpty {
                            newLines.append(currentSegment)
                            currentSegment = []
                        }
                    }
                }
                if !currentSegment.isEmpty {
                    newLines.append(currentSegment)
                }
            }
            manager.canvasProject.layers[index].content = .drawing(lines: newLines, color: color, thickness: thickness)
            
        default:
            // --- CAS STANDARD (Rectangle, Cercle, Image, Texte) ---
            let localMinX = selection.minX - (layer.x - layer.width / 2)
            let localMinY = selection.minY - (layer.y - layer.height / 2)
            
            manager.canvasProject.layers[index].cropLeft = max(0, localMinX)
            manager.canvasProject.layers[index].cropTop = max(0, localMinY)
            manager.canvasProject.layers[index].cropRight = max(0, layer.width - (localMinX + selection.width))
            manager.canvasProject.layers[index].cropBottom = max(0, layer.height - (localMinY + selection.height))
        }
        
        cancelCropMode()
    }

    // --- ASYNC & FILE MANAGEMENT LOGIC METHOD EXTRACTIONS ---
    
    private func importImage() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.image]
        
        if panel.runModal() == .OK, let url = panel.url {
            if let rawData = try? Data(contentsOf: url) {
                
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
                
                let currentProjectWidth = CGFloat(canvasWidth)
                let maxCanvasLimit = currentProjectWidth * 0.7
                
                if initialWidth > maxCanvasLimit {
                    initialWidth = maxCanvasLimit
                    initialHeight = initialWidth / ratio
                }
                
                let centerX = CGFloat(canvasWidth / 2)
                let centerY = CGFloat(canvasHeight / 2)
                
                manager.registerStateForUndo(undoManager: undoManager, previousState: manager.getLayers())
                manager.canvasProject.layers.append(Layer(
                    name: url.lastPathComponent,
                    x: centerX,
                    y: centerY,
                    width: initialWidth,
                    height: initialHeight,
                    content: .image(data: rawData, ratio: ratio)
                ))
            }
        }
    }
    
    @MainActor
    private func exportImage() {
        let drawingCanvas = DrawingCanvasView(
            manager: manager,
            undoManager: undoManager,
            startX: $startX,
            startY: $startY,
            isCropModeActive: $isCropModeActive,
            cropSelectionRect: $cropSelectionRect,
            cropTargetAll: $cropTargetAll
        )
        .frame(width: CGFloat(canvasWidth), height: CGFloat(canvasHeight))
        
        let backgroundLayerIndex = manager.getLayers().firstIndex(where: { $0.name == "Arrière-plan" })
        var isBackgroundTransparent = false
            
        if let index = backgroundLayerIndex {
            if case .transparent = manager[index].content {
                isBackgroundTransparent = true
            }
        }
        
        let originalVisibility = backgroundLayerIndex != nil ? (manager[backgroundLayerIndex!].isVisible ?? true) : true
        
        if let index = backgroundLayerIndex, isBackgroundTransparent {
            manager.canvasProject.layers[index].isVisible = false
        }
        
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.png, .pdf]
        savePanel.nameFieldStringValue = "mon_schema.png"
        savePanel.title = "Exporter le schéma"
        
        if savePanel.runModal() == .OK, let url = savePanel.url {
            if url.pathExtension.lowercased() == "pdf" {
                let pdfRenderer = ImageRenderer(content: drawingCanvas)
                pdfRenderer.render { size, context in
                    var box = CGRect(origin: .zero, size: size)
                    guard let cgContext = CGContext(url as CFURL, mediaBox: &box, nil) else { return }
                    
                    cgContext.beginPDFPage(nil)
                    context(cgContext)
                    cgContext.endPDFPage()
                    cgContext.closePDF()
                }
            } else {
                let renderer = ImageRenderer(content: drawingCanvas)
                renderer.scale = 2.0
                
                if let nsImage = renderer.nsImage {
                    if let tiffData = nsImage.tiffRepresentation,
                       let bitmapRep = NSBitmapImageRep(data: tiffData),
                       let pngData = bitmapRep.representation(using: .png, properties: [:]) {
                        try? pngData.write(to: url)
                    }
                }
            }
        }
        
        if let index = backgroundLayerIndex, isBackgroundTransparent {
            manager.canvasProject.layers[index].isVisible = originalVisibility
        }
    }
    
    private func saveProject() {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.json]
        savePanel.nameFieldStringValue = "mon_projet.json"
        
        if savePanel.runModal() == .OK, let url = savePanel.url {
            if let data = try? JSONEncoder().encode(manager.canvasProject) {
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
               let loadedProject = try? JSONDecoder().decode(CanvasProject.self, from: data) {
                // Chargement des données géométriques au niveau global
                self.canvasWidth = loadedProject.width
                self.canvasHeight = loadedProject.height
                self.manager.canvasProject = loadedProject
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
            if let rawData = try? Data(contentsOf: url) {
                
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
                    content: .image(data: rawData, ratio: ratio)
                )
                
                if let undoManager = undoManager {
                    undoManager.removeAllActions()
                }
                
                let canvasProject = CanvasProject(width: Double(initialWidth), height: Double(initialHeight), layers: [backgroundImageLayer])
                manager.canvasProject = canvasProject
                self.isProjectInitialized = true
            }
        }
    }
    
    private func copySelectedLayer() {
        guard let index = selectedLayerIndex, manager.getLayers().indices.contains(index) else { return }
        
        if let data = try? JSONEncoder().encode(manager[index]),
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
                let currentState = manager.getLayers()
                undoManager.registerUndo(withTarget: undoManager) { _ in
                    manager.canvasProject.layers = currentState
                }
            }
            
            manager.canvasProject.layers.append(newLayer)
            selectedLayerIndex = manager.getLayers().count - 1
        }
    }

    private func cutSelectedLayer() {
        copySelectedLayer()
        
        guard let index = selectedLayerIndex, manager.getLayers().indices.contains(index) else { return }
        
        if let undoManager = undoManager {
            let currentState = manager.getLayers()
            undoManager.registerUndo(withTarget: undoManager) { _ in
                manager.canvasProject.layers = currentState
            }
        }
        
        manager.canvasProject.layers.remove(at: index)
        selectedLayerIndex = nil
    }
    
    @MainActor
    private func copyImageToClipboard() {
        let sourceCanvas = DrawingCanvasView(
            manager: manager,
            undoManager: undoManager,
            startX: $startX,
            startY: $startY,
            isCropModeActive: $isCropModeActive,
            cropSelectionRect: $cropSelectionRect,
            cropTargetAll: $cropTargetAll
        )
        .frame(width: CGFloat(canvasWidth), height: CGFloat(canvasHeight))
            
        let renderer = ImageRenderer(content: sourceCanvas)
        renderer.scale = 2.0
        
        let backgroundLayerIndex = manager.getLayers().firstIndex(where: { $0.name == "Arrière-plan" })
        var isBackgroundTransparent = false
        
        if let index = backgroundLayerIndex {
            if case .transparent = manager[index].content {
                isBackgroundTransparent = true
            }
        }
        
        let originalVisibility = backgroundLayerIndex != nil ? (manager[backgroundLayerIndex!].isVisible ?? true) : true
        
        if let index = backgroundLayerIndex, isBackgroundTransparent {
            manager.canvasProject.layers[index].isVisible = false
        }
        
        if let nsImage = renderer.nsImage {
            if let index = backgroundLayerIndex, isBackgroundTransparent {
                manager.canvasProject.layers[index].isVisible = originalVisibility
            }
            
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.writeObjects([nsImage])
            
        } else {
            if let index = backgroundLayerIndex, isBackgroundTransparent {
                manager.canvasProject.layers[index].isVisible = originalVisibility
            }
        }
    }
}

struct HostingWindowFinder: NSViewRepresentable {
    var callback: (NSWindow?) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { [weak view] in
            callback(view?.window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

extension NSWindow {
    private struct AssociatedKeys {
        static var onScrollWheel: UInt8 = 0
    }

    var onScrollWheel: ((NSEvent) -> Void)? {
        get {
            objc_getAssociatedObject(self, &AssociatedKeys.onScrollWheel) as? (NSEvent) -> Void
        }
        set {
            objc_setAssociatedObject(self, &AssociatedKeys.onScrollWheel, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }

    open override func scrollWheel(with event: NSEvent) {
        if let block = onScrollWheel {
            block(event)
        }
        super.scrollWheel(with: event)
    }
}
