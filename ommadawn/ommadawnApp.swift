//
//  ommadawnApp.swift
//  ommadawn
//
//  Created by Rafael García on 23/07/2026.
//

import SwiftUI

@main
struct ommadawnApp: App {
    // La sesión vive tanto como la app y se comparte por el entorno.
    @State private var session = AuthSession()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(session)
                // Al arrancar: ¿hay sesión guardada? Valídala.
                .task { await session.restore() }
        }
    }
}
