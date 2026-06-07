import SwiftUI

struct SidebarView: View {
    @Binding var calques: [Calque]
    @Binding var indexSelectionne: Int?
    @Environment(\.undoManager) var undoManager
    
    @State private var afficherPopUpOptions = false
    @State private var configurationAvantPopUp: [Calque] = [] // Ajouté pour mémoriser l'état initial
    
    var body: some View {
        VStack(spacing: 15) {
            Text("Outils & Calques")
                .font(.headline)
                .padding(.top)
            
            VStack {
                HStack {
                    Button(action: {
                        let nouveauReg = Calque(nom: "Rectangle \(calques.count + 1)", x: 200, y: 200, largeur: 150, hauteur: 150, contenu: .rectangle(couleur: CodableColor(.blue.opacity(0.5))))
                        enregistrerEtatGlobalPourUndo()
                        calques.append(nouveauReg)
                    }) {
                        Image(systemName: "square.dashed")
                        Text("+ Rectangle")
                    }
                    
                    Button(action: {
                        let nouveauTexte = Calque(nom: "Texte \(calques.count + 1)", x: 180, y: 180, largeur: 200, hauteur: 50, contenu: .texte(contenu: "Nouveau Texte", couleur: CodableColor(.black), taille: 20, police: "Helvetica"))
                        enregistrerEtatGlobalPourUndo()
                        calques.append(nouveauTexte)
                    }) {
                        Image(systemName: "text.alignleft")
                        Text("+ Texte")
                    }
                }
                .padding(.horizontal)
                .buttonStyle(.bordered)
                
                HStack {
                    Button(action: {
                        let nouvelleFleche = Calque(
                            nom: "Flèche \(calques.count + 1)",
                            x: 0, y: 0, largeur: 0, hauteur: 0,
                            contenu: .fleche(depart: CGPoint(x: 100, y: 100), arrivee: CGPoint(x: 250, y: 100), couleur: CodableColor(.gray), style: .fin, epaisseur: 10)
                        )
                        enregistrerEtatGlobalPourUndo()
                        calques.append(nouvelleFleche)
                    }) {
                        Image(systemName: "arrow.up.forward")
                        Text("+ Flèche")
                    }
                    
                    Button(action: {
                        let nouveauCercle = Calque(
                            nom: "Cercle \(calques.count + 1)",
                            x: 150, y: 150, largeur: 100, hauteur: 100,
                            contenu: .cercle(couleur: CodableColor(.blue))
                        )
                        enregistrerEtatGlobalPourUndo()
                        calques.append(nouveauCercle)
                    }) {
                        Image(systemName: "circle")
                        Text("+ Cercle")
                    }
                    
                    Button(action: {
                        let largeurMax = calques.first?.largeur ?? 800
                        let hauteurMax = calques.first?.hauteur ?? 600
                        
                        let nouveauDessin = Calque(
                            nom: "Dessin \(calques.count + 1)",
                            x: largeurMax / 2,
                            y: hauteurMax / 2,
                            largeur: largeurMax,
                            hauteur: hauteurMax,
                            contenu: .dessin(lignes: [], couleur: CodableColor(.red), epaisseur: 4)
                        )
                        enregistrerEtatGlobalPourUndo()
                        calques.append(nouveauDessin)
                    }) {
                        Image(systemName: "scribble")
                        Text("+ Dessin libre")
                    }
                }
                .padding(.horizontal)
                .buttonStyle(.bordered)
            }
            
            Divider()
            
            // --- LISTE DES CALQUES ---
            List {
                ForEach(calques.indices.reversed(), id: \.self) { index in
                    rangeeCalque(pour: index)
                }
            }
            .listStyle(.sidebar)
        }
        .sheet(isPresented: $afficherPopUpOptions) {
            if let index = indexSelectionne, index < calques.count {
                OptionsCalqueView(
                    calque: $calques[index],
                    calques: $calques,
                    configurationInitiale: configurationAvantPopUp
                )
                .onDisappear {
                    if let dataActuelle = try? JSONEncoder().encode(calques),
                       let dataInitiale = try? JSONEncoder().encode(configurationAvantPopUp),
                       dataActuelle != dataInitiale {
                        if let undoManager = undoManager {
                            let copieDuPasse = configurationAvantPopUp
                            
                            // On cible NSApp pour éviter que macOS ne nettoie la pile à la fermeture de la vue
                            undoManager.registerUndo(withTarget: NSApp) { _ in
                                self.calques = copieDuPasse
                            }
                        }
                    }
                }
            }
        }
        .frame(width: 250)
    }
    
    // --- COMPOSANT ISOLÉ POUR ÉVITER LE BUG DE TYPE-CHECK DE XCODE ---
    private func rangeeCalque(pour index: Int) -> some View {
        HStack {
            Text(calques[index].nom)
            Spacer()
            
            Button(action: { monterCalque(at: index) }) {
                Image(systemName: "chevron.up")
            }
            .buttonStyle(.borderless)
            .disabled(index == calques.count - 1)
            
            Button(action: { descendreCalque(at: index) }) {
                Image(systemName: "chevron.down")
            }
            .buttonStyle(.borderless)
            .disabled(index == 0)
            
            Button(action: { supprimerCalque(at: index) }) {
                Image(systemName: "xmark.circle.fill")
            }
            .buttonStyle(.borderless)
            .foregroundColor(.red)
            
            Button(action: {
                indexSelectionne = index
                if let data = try? JSONEncoder().encode(calques) {
                    self.configurationAvantPopUp = (try? JSONDecoder().decode([Calque].self, from: data)) ?? []
                }
                afficherPopUpOptions = true
            }) {
                Image(systemName: "gearshape.fill")
            }
            .buttonStyle(.borderless)
            
            Button(action: {
                calques[index].estVisible = !(calques[index].estVisible ?? true)
            }) {
                Image(systemName: (calques[index].estVisible ?? true) ? "eye" : "eye.slash")
                    .foregroundColor((calques[index].estVisible ?? true) ? .blue : .gray)
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 4)
        .background(indexSelectionne == index ? Color.blue.opacity(0.2) : Color.clear)
        .onTapGesture {
            indexSelectionne = index
        }
    }
    
    // --- GESTIONNAIRES D'ACTIONS ENCAPSULÉS ---
    private func enregistrerEtatGlobalPourUndo() {
        if let undoManager = undoManager {
            let etatActuel = calques
            undoManager.registerUndo(withTarget: NSApp) { _ in
                self.calques = etatActuel
            }
        }
    }
    
    private func monterCalque(at index: Int) {
        if index < calques.count - 1 {
            enregistrerEtatGlobalPourUndo()
            calques.swapAt(index, index + 1)
            if indexSelectionne == index { indexSelectionne = index + 1 }
        }
    }
    
    private func descendreCalque(at index: Int) {
        if index > 0 {
            enregistrerEtatGlobalPourUndo()
            calques.swapAt(index, index - 1)
            if indexSelectionne == index { indexSelectionne = index - 1 }
        }
    }
    
    private func supprimerCalque(at index: Int) {
        enregistrerEtatGlobalPourUndo()
        calques.remove(at: index)
        indexSelectionne = nil
    }
}
