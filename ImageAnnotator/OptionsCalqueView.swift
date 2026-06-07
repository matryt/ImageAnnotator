import SwiftUI

struct OptionsCalqueView: View {
    @Binding var calque: Calque
    @Binding var calques: [Calque] // Reçoit la liste globale pour connaître les limites max de l'Arrière-plan
    @Environment(\.dismiss) var dismiss
    @Environment(\.undoManager) var undoManager
    let configurationInitiale: [Calque]
    
    let policesDisponibles = [
        "Helvetica", "Arial", "Courier New", "Times New Roman",
        "Avenir Next", "American Typewriter", "Marker Felt"
    ]

    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Options du calque : \(calque.nom)")
                .font(.title2)
                .bold()
            
            // On calcule dynamiquement le garde-fou pour les Sliders
            let largeurMaxProjet = calques.first?.largeur ?? 800
            let hauteurMaxProjet = calques.first?.hauteur ?? 600
            
            // --- SECTION SPECIFIQUE SELON LE CONTENU ---
            switch calque.contenu { // S'adapte si ta variable s'appelle 'contenu' ou 'contents'
            
            case .texte(let contenu, let couleur, let taille, let nomPolice):
                let policeBinding = Binding(
                    get: { nomPolice },
                    set: {
                        calque.contenu = .texte(contenu: contenu, couleur: couleur, taille: taille, police: $0)
                    }
                )
                
                let couleurTexteBinding = Binding<Color>(
                    get: { couleur.asColor },
                    set: {
                        calque.contenu = .texte(contenu: contenu, couleur: CodableColor($0), taille: taille, police: nomPolice)
                    }
                )
                
                Section(header: Text("Style du Texte").font(.headline)) {
                    Picker("Police d'écriture :", selection: policeBinding) {
                        ForEach(policesDisponibles, id: \.self) { police in
                            Text(police).font(.custom(police, size: 14))
                        }
                    }
                    
                    HStack {
                        Text("Taille de la police : \(Int(taille))")
                        // Le Binding de valeur est direct, l'Undo s'active uniquement au clic de la souris
                        Slider(
                            value: Binding(
                                get: { taille },
                                set: { calque.contenu = .texte(contenu: contenu, couleur: couleur, taille: $0, police: nomPolice) }
                            ),
                            in: 10...100,
                        )
                    }
                    
                    HStack {
                        Text("Couleur de la police :")
                        ColorPicker("", selection: couleurTexteBinding)
                    }
                }
                
            case .rectangle(let couleur):
                let proportionGardeeBinding = Binding<Bool>(
                    get: { calque.largeur == calque.hauteur },
                    set: { rendreParfait in
                        if rendreParfait {
                            calque.hauteur = calque.largeur
                        } else {
                            calque.hauteur = calque.largeur - 1
                        }
                    }
                )
                
                Section(header: Text("Dimensions du Rectangle").font(.headline)) {
                    Toggle("Carré parfait (Bloquer le ratio)", isOn: proportionGardeeBinding)
                        .padding(.bottom, 5)
                    
                    HStack {
                        Text("Largeur : \(Int(calque.largeur))px")
                        Slider(
                            value: Binding(
                                get: { calque.largeur },
                                set: { nouvelleLargeur in
                                    let etaitParfait = calque.largeur == calque.hauteur
                                    calque.largeur = nouvelleLargeur
                                    if etaitParfait { calque.hauteur = nouvelleLargeur }
                                }
                            ),
                            in: 10...largeurMaxProjet,
                        )
                    }
                    
                    if calque.largeur != calque.hauteur {
                        HStack {
                            Text("Hauteur : \(Int(calque.hauteur))px")
                            Slider(
                                value: $calque.hauteur,
                                in: 10...hauteurMaxProjet,
                            )
                        }
                    } else {
                        Text("Hauteur automatique : \(Int(calque.hauteur))px")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                
                let couleurRectangleBinding = Binding<Color>(
                    get: { couleur.asColor },
                    set: {
                        calque.contenu = .rectangle(couleur: CodableColor($0))
                    }
                )
                
                Section(header: Text("Style").font(.headline)) {
                    ColorPicker("Couleur du rectangle :", selection: couleurRectangleBinding)
                }

            case .cercle(let couleur):
                let proportionGardeeBinding = Binding<Bool>(
                    get: { calque.largeur == calque.hauteur },
                    set: { rendreParfait in
                        if rendreParfait {
                            calque.hauteur = calque.largeur
                        } else {
                            calque.hauteur = calque.largeur - 1
                        }
                    }
                )
                
                Section(header: Text("Dimensions du Cercle").font(.headline)) {
                    Toggle("Cercle parfait (Bloquer le ratio)", isOn: proportionGardeeBinding)
                        .padding(.bottom, 5)
                    
                    HStack {
                        Text("Largeur : \(Int(calque.largeur))px")
                        Slider(
                            value: Binding(
                                get: { calque.largeur },
                                set: { nouvelleLargeur in
                                    let estParfait = calque.largeur == calque.hauteur
                                    calque.largeur = nouvelleLargeur
                                    if estParfait { calque.hauteur = nouvelleLargeur }
                                }
                            ),
                            in: 10...largeurMaxProjet,
                        )
                    }
                    
                    if calque.largeur != calque.hauteur {
                        HStack {
                            Text("Hauteur : \(Int(calque.hauteur))px")
                            Slider(
                                value: $calque.hauteur,
                                in: 10...hauteurMaxProjet,
                            )
                        }
                    } else {
                        Text("Hauteur automatique : \(Int(calque.hauteur))px")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                
                let couleurCercleBinding = Binding<Color>(
                    get: { couleur.asColor },
                    set: {
                        calque.contenu = .cercle(couleur: CodableColor($0))
                    }
                )
                
                Section(header: Text("Style").font(.headline)) {
                    ColorPicker("Couleur du cercle :", selection: couleurCercleBinding)
                }
                
            case .fleche(let ptDepart, let ptArrivee, let couleur, let stylePointe, let epaisseur):
                let stylePointeBinding = Binding(
                    get: { stylePointe },
                    set: {
                        calque.contenu = .fleche(depart: ptDepart, arrivee: ptArrivee, couleur: couleur, style: $0, epaisseur: epaisseur)
                    }
                )
                
                let couleurFlecheBinding = Binding<Color>(
                    get: { couleur.asColor },
                    set: {
                        calque.contenu = .fleche(depart: ptDepart, arrivee: ptArrivee, couleur: CodableColor($0), style: stylePointe, epaisseur: epaisseur)
                    }
                )

                Section(header: Text("Style de la Flèche").font(.headline)) {
                    ColorPicker("Couleur de la ligne :", selection: couleurFlecheBinding)
                    
                    HStack {
                        Text("Épaisseur : \(Int(epaisseur))px")
                        Slider(
                            value: Binding(
                                get: { epaisseur },
                                set: { calque.contenu = .fleche(depart: ptDepart, arrivee: ptArrivee, couleur: couleur, style: stylePointe, epaisseur: $0) }
                            ),
                            in: 2...20,
                        )
                    }
                    
                    Picker("Type de flèche :", selection: stylePointeBinding) {
                        ForEach(StylePointe.allCases) { style in
                            Text(style.rawValue).tag(style)
                        }
                    }
                }
                
            case .image(_, let ratioDOrigine):
                Section(header: Text("Taille de l'image (Ratio conservé)").font(.headline)) {
                    HStack {
                        Text("Largeur : \(Int(calque.largeur))px")
                        Slider(
                            value: Binding(
                                get: { calque.largeur },
                                set: { nouvelleLargeur in
                                    let largBridee = min(nouvelleLargeur, largeurMaxProjet)
                                    calque.largeur = largBridee
                                    calque.hauteur = largBridee / ratioDOrigine
                                }
                            ),
                            in: 50...largeurMaxProjet,
                        )
                    }
                    HStack {
                        Text("Hauteur automatique : \(Int(calque.hauteur))px")
                            .foregroundColor(.gray)
                    }
                }
                
                Section(header: Text("Recadrer les 4 côtés").font(.headline)) {
                    // --- BORD GAUCHE ---
                    HStack {
                        Text("Rogner Gauche :")
                        Slider(
                            value: Binding(
                                get: { calque.cropGauche ?? 0 },
                                set: { nouvelleCoupe in
                                    let ancienneCoupe = calque.cropGauche ?? 0
                                    let difference = nouvelleCoupe - ancienneCoupe
                                    if calque.largeur - difference > 10 {
                                        calque.cropGauche = nouvelleCoupe
                                        calque.largeur -= difference
                                        calque.x += difference / 2
                                    }
                                }
                            ),
                            in: 0...400,
                        )
                    }
                    
                    // --- BORD DROIT ---
                    HStack {
                        Text("Rogner Droit :")
                        Slider(
                            value: Binding(
                                get: { calque.cropDroite ?? 0 },
                                set: { nouvelleCoupe in
                                    let ancienneCoupe = calque.cropDroite ?? 0
                                    let difference = nouvelleCoupe - ancienneCoupe
                                    if calque.largeur - difference > 10 {
                                        calque.cropDroite = nouvelleCoupe
                                        calque.largeur -= difference
                                        calque.x -= difference / 2
                                    }
                                }
                            ),
                            in: 0...400,
                        )
                    }
                    
                    // --- BORD HAUT ---
                    HStack {
                        Text("Rogner Haut :")
                        Slider(
                            value: Binding(
                                get: { calque.cropHaut ?? 0 },
                                set: { nouvelleCoupe in
                                    let ancienneCoupe = calque.cropHaut ?? 0
                                    let difference = nouvelleCoupe - ancienneCoupe
                                    if calque.hauteur - difference > 10 {
                                        calque.cropHaut = nouvelleCoupe
                                        calque.hauteur -= difference
                                        calque.y += difference / 2
                                    }
                                }
                            ),
                            in: 0...400,
                        )
                    }
                    
                    // --- BORD BAS ---
                    HStack {
                        Text("Rogner Bas :")
                        Slider(
                            value: Binding(
                                get: { calque.cropBas ?? 0 },
                                set: { nouvelleCoupe in
                                    let ancienneCoupe = calque.cropBas ?? 0
                                    let difference = nouvelleCoupe - ancienneCoupe
                                    if calque.hauteur - difference > 10 {
                                        calque.cropBas = nouvelleCoupe
                                        calque.hauteur -= difference
                                        calque.y -= difference / 2
                                    }
                                }
                            ),
                            in: 0...400,
                        )
                    }
                }
                
            case .dessin(let lignes, let couleur, let epaisseur):
                let couleurBinding = Binding<Color>(
                    get: { couleur.asColor },
                    set: {
                        calque.contenu = .dessin(lignes: lignes, couleur: CodableColor($0), epaisseur: epaisseur)
                    }
                )

                Section(header: Text("Style du Tracé à main levée").font(.headline)) {
                    HStack {
                        Text("Épaisseur du trait : \(Int(epaisseur))px")
                        Slider(
                            value: Binding(
                                get: { epaisseur },
                                set: { calque.contenu = .dessin(lignes: lignes, couleur: couleur, epaisseur: $0) }
                            ),
                            in: 1...30,
                        )
                    }
                    ColorPicker("Couleur du pinceau :", selection: couleurBinding)
                }
                
            default:
                Text("Aucune option de style avancée pour ce type de calque.")
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            // Bouton de fermeture
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
