//
//  ommadawnApp.swift
//  ommadawn
//
//  Created by Rafael García on 23/07/2026.
//

import SwiftUI
import GoogleSignIn

@main
struct ommadawnApp: App {
    // La sesión vive tanto como la app y se comparte por el entorno.
    @State private var session = AuthSession()

    init() {
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(
            clientID: GoogleAuthConfig.clientID,
            serverClientID: GoogleAuthConfig.serverClientID
        )
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(session)
                // Al arrancar: ¿hay sesión guardada? Valídala.
                .task { await session.restore() }
                // El SDK de Google necesita esta puerta de vuelta tras el login
                // en el navegador embebido (ASWebAuthenticationSession por debajo).
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                }
        }
    }
}
