import SwiftUI
import UniformTypeIdentifiers
import Combine

@MainActor
class ProjetManager: ObservableObject {
    @Published var calques: [Calque] = []
    
    func enregistrerEtatPourUndo(undoManager: UndoManager?, ancienEtat: [Calque]) {
        guard let undoManager = undoManager else { return }
        
        undoManager.registerUndo(withTarget: self) { manager in
            let etatActuel = manager.calques
            manager.enregistrerEtatPourUndo(undoManager: undoManager, ancienEtat: etatActuel)
            manager.calques = ancienEtat
        }
    }
}

struct ContentView: View {
    @StateObject private var manager = ProjetManager()
    @Environment(\.undoManager) var undoManager
    
    @State private var startX: CGFloat = 0
    @State private var startY: CGFloat = 0
    
    @State private var indexCalqueSelectionne: Int? = nil
    
    @State private var largeurCanevas: Double = 800
    @State private var hauteurCanevas: Double = 600
    @State private var couleurFond: Color = .white
    @State private var fondTransparent = false
    @State private var projetInitialise: Bool = false
    
    private func enregistrerEtatPourUndo(ancienEtat: [Calque]) {
        manager.enregistrerEtatPourUndo(undoManager: undoManager, ancienEtat: ancienEtat)
    }
    
    var zonedeDessin: some View {
        ZStack {
            // On boucle directement sur le manager
            ForEach(manager.calques.indices, id: \.self) { index in
                if (manager.calques[index].estVisible ?? true) {
                    switch manager.calques[index].contenu {
                    case .fleche, .dessin:
                        // Correction syntaxe ici : Le binding se fait via le manager directement
                        ElementCalqueView(calque: $manager.calques[index])
                        
                    default:
                        ElementCalqueView(calque: $manager.calques[index])
                            .position(x: manager.calques[index].x, y: manager.calques[index].y)
                            .gesture(
                                DragGesture()
                                    .onChanged { gesture in
                                        if startX == 0 && startY == 0 {
                                            // Enregistrement de l'historique au premier clic
                                            enregistrerEtatPourUndo(ancienEtat: manager.calques)
                                            startX = manager.calques[index].x
                                            startY = manager.calques[index].y
                                        }
                                        
                                        let limiteX = manager.calques.first?.largeur ?? CGFloat(largeurCanevas)
                                        let limiteY = manager.calques.first?.hauteur ?? CGFloat(hauteurCanevas)
                                        
                                        let cibleX = startX + gesture.translation.width
                                        let cibleY = startY + gesture.translation.height
                                        
                                        // On modifie l'objet en direct sans passer par un $
                                        manager.calques[index].x = max(0, min(cibleX, limiteX))
                                        manager.calques[index].y = max(0, min(cibleY, limiteY))
                                    }
                                    .onEnded { _ in
                                        startX = 0
                                        startY = 0
                                    }
                            )
                    }
                }
            }
        }
        .frame(
            width: manager.calques.first?.largeur ?? CGFloat(largeurCanevas),
            height: manager.calques.first?.hauteur ?? CGFloat(hauteurCanevas)
        )
        .background(manager.calques.first?.nom == "Arrière-plan" ? Color.clear : Color.white)
        .clipped()
    }
    
    var body: some View {
        if !projetInitialise {
            VStack(spacing: 20) {
                Text("Créer un nouveau canevas")
                    .font(.title)
                    .bold()
                
                Form {
                    TextField("Largeur (px) :", value: $largeurCanevas, format: .number)
                    TextField("Hauteur (px) :", value: $hauteurCanevas, format: .number)
                    
                    Toggle("Fond transparent", isOn: $fondTransparent)
                    
                    if !fondTransparent {
                        ColorPicker("Couleur de fond :", selection: $couleurFond)
                    }
                }
                .frame(width: 300)
                
                Button("Créer le canevas") {
                    let calqueFond: Calque
                    if fondTransparent {
                        calqueFond = Calque(nom: "Arrière-plan", x: CGFloat(largeurCanevas / 2), y: CGFloat(hauteurCanevas / 2), largeur: CGFloat(largeurCanevas), hauteur: CGFloat(hauteurCanevas), contenu: .transparent(val: true))
                    } else {
                        calqueFond = Calque(
                            nom: "Arrière-plan",
                            x: CGFloat(largeurCanevas / 2),
                            y: CGFloat(hauteurCanevas / 2),
                            largeur: CGFloat(largeurCanevas),
                            hauteur: CGFloat(hauteurCanevas),
                            contenu: .rectangle(couleur: CodableColor(couleurFond))
                        )
                    }
                    
                    enregistrerEtatPourUndo(ancienEtat: manager.calques)
                    manager.calques.append(calqueFond)
                    projetInitialise = true
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                
                Button("Ouvrir un projet existant") {
                    chargerProjet()
                }
                .buttonStyle(.borderless)
                .padding(.top, 5)
            }
            .frame(minWidth: 500, minHeight: 400)
            
        } else {
            HStack(spacing: 0) {
                // Modifié ici pour passer le binding du manager
                SidebarView(calques: $manager.calques, indexSelectionne: $indexCalqueSelectionne)
                
                Divider()
                
                GeometryReader { geometry in
                    ZStack {
                        Color(nsColor: .windowBackgroundColor)
                        zonedeDessin
                            .shadow(radius: 8)
                    }
                }
            }
            .focusedSceneValue(\.undoManager, undoManager)
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("DeclencherImport"))) { _ in
                importerUneImage()
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("DeclencherExport"))) { _ in
                exporterImage()
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("OuvrirProjet"))) { _ in
                chargerProjet()
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("EnregistrerProjet"))) { _ in
                sauvegarderProjet()
            }
        }
    }

    private func importerUneImage() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.image]
        
        if panel.runModal() == .OK, let url = panel.url {
            if let bookmarkData = try? url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil) {
                
                var largeurInitiale: CGFloat = 300
                var hauteurInitiale: CGFloat = 200
                var ratio: CGFloat = 1.5
                
                if let nsImage = NSImage(contentsOf: url) {
                    largeurInitiale = nsImage.size.width
                    hauteurInitiale = nsImage.size.height
                    if hauteurInitiale > 0 {
                        ratio = largeurInitiale / hauteurInitiale
                    }
                }
                
                let tailleProjetActuelle = manager.calques.first?.largeur ?? CGFloat(largeurCanevas)
                let limiteMaxCanevas = tailleProjetActuelle * 0.7
                
                if largeurInitiale > limiteMaxCanevas {
                    largeurInitiale = limiteMaxCanevas
                    hauteurInitiale = largeurInitiale / ratio
                }
                
                let centreX = (manager.calques.first?.largeur ?? CGFloat(largeurCanevas)) / 2
                let centreY = (manager.calques.first?.hauteur ?? CGFloat(hauteurCanevas)) / 2
                
                enregistrerEtatPourUndo(ancienEtat: manager.calques)
                manager.calques.append(Calque(
                    nom: url.lastPathComponent,
                    x: centreX,
                    y: centreY,
                    largeur: largeurInitiale,
                    hauteur: hauteurInitiale,
                    contenu: .image(data: bookmarkData, ratio: ratio)
                ))
            }
        }
    }
    
    @MainActor
    private func exporterImage() {
        let renderer = ImageRenderer(content: zonedeDessin)
        renderer.scale = 2.0
        
        if let nsImage = renderer.nsImage {
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
        }
    }
    
    private func sauvegarderProjet() {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.json]
        savePanel.nameFieldStringValue = "mon_projet.json"
        
        if savePanel.runModal() == .OK, let url = savePanel.url {
            if let data = try? JSONEncoder().encode(manager.calques) {
                try? data.write(to: url)
            }
        }
    }

    private func chargerProjet() {
        let openPanel = NSOpenPanel()
        openPanel.allowedContentTypes = [.json]
        openPanel.allowsMultipleSelection = false
        
        if openPanel.runModal() == .OK, let url = openPanel.url {
            if let data = try? Data(contentsOf: url),
               let calquesCharges = try? JSONDecoder().decode([Calque].self, from: data) {
                self.manager.calques = calquesCharges
                self.projetInitialise = true
            }
        }
    }
}
