//
//  Canvas.swift
//  ImageAnnotator
//
//  Created by Mathieu CUVELIER on 03/06/2026.
//

import Foundation
import SwiftUI

enum StylePointe: String, CaseIterable, Identifiable, Codable {
    case fin = "À la fin"
    case debut = "Au début"
    case deuxCotes = "Des deux côtés"
    case aucun = "Simple ligne"
    
    var id: String { self.rawValue }
}

// 1. On définit les "Types" de contenus uniques possibles
enum TypeContenu: Equatable, Hashable, Codable {
    case rectangle(couleur: CodableColor)
    case texte(contenu: String, couleur: CodableColor, taille: CGFloat, police: String)
    case image(data: Data, ratio: CGFloat) // Pour plus tard !
    case fleche(depart: CGPoint, arrivee: CGPoint, couleur: CodableColor, style: StylePointe, epaisseur: CGFloat)
    case transparent(val: Bool)
    case cercle(couleur: CodableColor)
    case dessin(lignes: [[CGPoint]], couleur: CodableColor, epaisseur: CGFloat)
}

// 2. Le calque reste la structure globale qui gère le positionnement
struct Calque: Identifiable, Hashable, Equatable, Codable {
    var id = UUID()
    var nom: String
    
    // Propriétés communes à TOUS les calques
    var x: CGFloat
    var y: CGFloat
    var largeur: CGFloat
    var hauteur: CGFloat
    
    // Le contenu spécifique du calque
    var contenu: TypeContenu
    var opacite: Double? = 1.0
    
    var cropGauche: CGFloat? = 0
    var cropDroite: CGFloat? = 0
    var cropHaut: CGFloat? = 0
    var cropBas: CGFloat? = 0
    
    var estVisible: Bool? = true
    
    enum CodingKeys: String, CodingKey {
            case nom, x, y, largeur, hauteur, contenu, opacite, cropGauche, cropDroite, cropHaut, cropBas, estVisible
    }
}

struct CodableColor: Codable, Hashable, Equatable {
    var red: Double
    var green: Double
    var blue: Double
    var alpha: Double

    // Convertit une Color SwiftUI en CodableColor
    init(_ color: Color) {
        let nsColor = NSColor(color)
                if let rgbColor = nsColor.usingColorSpace(.sRGB) {
                    self.red = Double(rgbColor.redComponent)
                    self.green = Double(rgbColor.greenComponent)
                    self.blue = Double(rgbColor.blueComponent)
                    self.alpha = Double(rgbColor.alphaComponent)
                } else {
                    // Sécurité au cas où la conversion échoue (fond blanc par défaut)
                    self.red = 1.0
                    self.green = 1.0
                    self.blue = 1.0
                    self.alpha = 1.0
                }
    }

    // Convertit la CodableColor en vraie Color SwiftUI
    var asColor: Color {
        Color(nsColor: NSColor(red: CGFloat(red), green: CGFloat(green), blue: CGFloat(blue), alpha: CGFloat(alpha)))
    }
}

struct UndoManagerKey: FocusedValueKey {
    typealias Value = UndoManager
}

extension FocusedValues {
    var undoManager: UndoManager? {
        get { self[UndoManagerKey.self] }
        set { self[UndoManagerKey.self] = newValue }
    }
}
