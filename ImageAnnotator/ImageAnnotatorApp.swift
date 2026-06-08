//
//  ImageAnnotatorApp.swift
//  ImageAnnotator
//
//  Created by Mathieu CUVELIER on 03/06/2026.
//

import SwiftUI

@main
struct ImageAnnotatorApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        
        .commands {
                    CommandGroup(replacing: .importExport) {
                        Button("Importer une image...") {
                            // On va déclencher l'importation via une notification système
                            NotificationCenter.default.post(name: NSNotification.Name("DeclencherImport"), object: nil)
                        }
                        .keyboardShortcut("i", modifiers: .command) // Cmd + I
                        
                        Button("Exporter l'image finale...") {
                            // On va déclencher l'exportation
                            NotificationCenter.default.post(name: NSNotification.Name("DeclencherExport"), object: nil)
                        }
                        .keyboardShortcut("s", modifiers: .command) // Cmd + S
                        
                        Button("Ouvrir un projet") {
                            // On va déclencher l'exportation
                            NotificationCenter.default.post(name: NSNotification.Name("OuvrirProjet"), object: nil)
                        }
                        .keyboardShortcut("o", modifiers: .command) // Cmd + O
                        
                        Button("Enregistrer le projet") {
                            NotificationCenter.default.post(name: NSNotification.Name("EnregistrerProjet"), object: nil)
                        }
                        .keyboardShortcut("d", modifiers: .command)
                    }
            
                    CommandGroup(after: .pasteboard) {
                            Divider()
                            
                            Button("Copier l'image complète") {
                                NotificationCenter.default.post(
                                    name: NSNotification.Name("DeclencherCopiePressePapiers"),
                                    object: nil
                                )
                            }
                            .keyboardShortcut("c", modifiers: [.command, .shift])
                    }
                }
    }
}
