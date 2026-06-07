import SwiftUI

struct FlecheShape: Shape {
    let depart: CGPoint
    let arrivee: CGPoint
    let stylePointe: StylePointe
    let epaisseur: CGFloat
    
    func path(in rect: CGRect) -> Path {
            var path = Path()
            
            // 1. La ligne principale reste identique
            path.move(to: depart)
            path.addLine(to: arrivee)
            
            // Calcul de l'angle pour la pointe à l'arrivée (Pointe B)
            let angleArrivee = atan2(arrivee.y - depart.y, arrivee.x - depart.x)
            // Calcul de l'angle inversé pour la pointe au départ (Pointe A)
            let angleDepart = atan2(depart.y - arrivee.y, depart.x - arrivee.x)
            
            // La taille de la tête s'adapte proportionnellement à l'épaisseur de la ligne !
            let longueurTete = 10 + (epaisseur * 1.5)
            let angleAiles = CGFloat.pi / 6
            
            // 2. Dessiner la pointe à l'ARRIVÉE (si demandé)
            if stylePointe == .fin || stylePointe == .deuxCotes {
                ajouterTeteDeFleche(at: arrivee, angle: angleArrivee, longueur: longueurTete, angleAiles: angleAiles, into: &path)
            }
            
            // 3. Dessiner la pointe au DÉPART (si demandé)
            if stylePointe == .debut || stylePointe == .deuxCotes {
                ajouterTeteDeFleche(at: depart, angle: angleDepart, longueur: longueurTete, angleAiles: angleAiles, into: &path)
            }
            
            return path
        }
        
        // Petite fonction utilitaire pour éviter de répéter le code des ailes
        private func ajouterTeteDeFleche(at point: CGPoint, angle: CGFloat, longueur: CGFloat, angleAiles: CGFloat, into path: inout Path) {
            let aileGauche = CGPoint(
                x: point.x - longueur * cos(angle - angleAiles),
                y: point.y - longueur * sin(angle - angleAiles)
            )
            path.move(to: point)
            path.addLine(to: aileGauche)
            
            let aileDroite = CGPoint(
                x: point.x - longueur * cos(angle + angleAiles),
                y: point.y - longueur * sin(angle + angleAiles)
            )
            path.move(to: point)
            path.addLine(to: aileDroite)
        }
}
