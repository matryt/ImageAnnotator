import SwiftUI

struct ElementCalqueView: View {
    @Binding var calque: Calque
    @State private var estEnEdition: Bool = false
    
    @Environment(\.undoManager) var undoManager
    
    var body: some View {
        ZStack {
            switch calque.contenu {
                
            case .rectangle(let couleur):
                Rectangle()
                    .foregroundStyle(couleur.asColor)
                    .frame(width: calque.largeur, height: calque.hauteur)
                    .opacity(calque.opacite ?? 1)
                    
            case .texte(let contenu, let couleur, let taille, let police):
                            if estEnEdition {
                                // 1. On crée un Binding à la volée pour que le TextField puisse modifier le tableau
                                let textBinding = Binding(
                                    get: { contenu },
                                    set: { calque.contenu = .texte(contenu: $0, couleur: couleur, taille: taille, police: police) }
                                )
                                
                                // 2. On affiche le champ de saisie directement sur le calque
                                TextField("", text: textBinding, onCommit: {
                                    estEnEdition = false // Quand il appuie sur Entrée, on valide et on ferme
                                })
                                .textFieldStyle(.plain) // Pas de bordure laide pour que ça reste joli
                                .font(.custom(police, size: taille))
                                .foregroundStyle(couleur.asColor)
                                .frame(width: calque.largeur)
                                
                            } else {
                                // 3. Mode lecture normal
                                Text(contenu)
                                    .font(.custom(police, size: taille))
                                    .foregroundStyle(couleur.asColor)
                                    .opacity(calque.opacite ?? 1)
                                    // Le fameux détecteur de double-clic !
                                    .onTapGesture(count: 2) {
                                        estEnEdition = true
                                    }
                            }
                    
            case .image(let bookmarkData, _):
                if let nsImage = chargerImageDepuisSignet(bookmarkData: bookmarkData) {
                    let cGauche = calque.cropGauche ?? 0
                    let cDroite = calque.cropDroite ?? 0
                    let cHaut = calque.cropHaut ?? 0
                    let cBas = calque.cropBas ?? 0
                    
                    Image(nsImage: nsImage)
                        .resizable()
                        .scaledToFill()
                        // On applique le décalage de la texture à l'intérieur
                        .offset(x: (cDroite - cGauche) / 2, y: (cBas - cHaut) / 2)
                        // On applique les VRAIES dimensions du calque, qui sont saines !
                        .frame(width: calque.largeur, height: calque.hauteur)
                        .clipped()
                        .opacity(calque.opacite ?? 1)
                }
                
            case .fleche(let ptDepart, let ptArrivee, let couleur, let style, let epaisseur):
                ZStack {
                    // 1. Le dessin de la flèche (toujours visible)
                    FlecheShape(depart: ptDepart, arrivee: ptArrivee, stylePointe: style, epaisseur: epaisseur)
                        .stroke(couleur.asColor, style: StrokeStyle(lineWidth: epaisseur, lineCap: .round, lineJoin: .round))
                        // ASTUCE : Permet de cliquer n'importe où sur la ligne, pas juste sur les pixels exacts
                        .contentShape(Rectangle())
                        .onTapGesture {
                            // Un simple clic sur la flèche active/désactive les points bleus !
                            estEnEdition.toggle()
                        }
                    
                    // 2. Les poignées s'affichent selon l'état local du composant
                    if estEnEdition {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 12, height: 12)
                            .position(ptDepart)
                            .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        calque.contenu = .fleche(depart: value.location, arrivee: ptArrivee, couleur: couleur, style: style, epaisseur: epaisseur)
                                    }
                            )
                        
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 12, height: 12)
                            .position(ptArrivee)
                            .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        calque.contenu = .fleche(depart: ptDepart, arrivee: value.location, couleur: couleur, style: style, epaisseur: epaisseur)
                                    }
                            )
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
            case .transparent:
                Canvas { context, size in
                            let tailleCarre: CGFloat = 10
                            for x in stride(from: 0, to: size.width, by: tailleCarre) {
                                for y in stride(from: 0, to: size.height, by: tailleCarre) {
                                    // On alterne les carrés blancs et gris clairs
                                    let estGris = (Int(x / tailleCarre) + Int(y / tailleCarre)) % 2 == 0
                                    let rectangle = CGRect(x: x, y: y, width: tailleCarre, height: tailleCarre)
                                    context.fill(Path(rectangle), with: .color(estGris ? Color(nsColor: .lightGray).opacity(0.3) : .white))
                                }
                            }
                        }
                
            case .cercle(let couleur):
                Ellipse() // Permet de faire des ronds parfaits ou des ovales selon largeur/hauteur
                    .foregroundStyle(couleur.asColor)
                    .frame(width: calque.largeur, height: calque.hauteur)
                    .opacity(calque.opacite ?? 1)
            
            case .dessin(let lignes, let couleur, let epaisseur):
                Canvas { context, size in
                    // On dessine chaque coup de crayon indépendamment
                    for ligne in lignes {
                        var path = Path()
                        guard let premierPoint = ligne.first else { continue }
                        path.move(to: premierPoint)
                        
                        for point in ligne.dropFirst() {
                            path.addLine(to: point)
                        }
                        
                        context.stroke(path, with: .color(couleur.asColor), style: StrokeStyle(lineWidth: epaisseur, lineCap: .round, lineJoin: .round))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            var nouvellesLignes = lignes
                            
                            if value.translation == .zero {
                                if let undoManager = undoManager {
                                    // On crée une sauvegarde profonde des lignes actuelles avant la modification
                                    let configurationPrecedente = lignes
                                    undoManager.registerUndo(withTarget: undoManager) { _ in
                                        calque.contenu = .dessin(lignes: configurationPrecedente, couleur: couleur, epaisseur: epaisseur)
                                    }
                                }
                                nouvellesLignes.append([value.location])
                            } else {
                                if let indexDerniereLigne = nouvellesLignes.indices.last {
                                    nouvellesLignes[indexDerniereLigne].append(value.location)
                                }
                            }
                            
                            calque.contenu = .dessin(lignes: nouvellesLignes, couleur: couleur, epaisseur: epaisseur)
                        }
                )
            }
        }
    }
    
    private func chargerImageDepuisSignet(bookmarkData: Data) -> NSImage? {
        var stale = false
        guard let url = try? URL(resolvingBookmarkData: bookmarkData, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &stale) else {
            return nil
        }
        
        let aAcces = url.startAccessingSecurityScopedResource()
        let img = NSImage(contentsOf: url)
        if aAcces { url.stopAccessingSecurityScopedResource() }
        
        return img
    }
}
