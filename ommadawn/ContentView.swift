//8
//  ContentView.swift
//  ommadawn
//

import SwiftUI
import OmmadawnAPI

/// Vista raíz. Enruta según el estado de la sesión:
///   - `loading`   → mientras se comprueba si hay sesión guardada
///   - `signedOut` → pantalla de login
///   - `signedIn`  → app (por ahora, HomeView placeholder)
struct ContentView: View {
    @Environment(AuthSession.self) private var session

    var body: some View {
        switch session.state {
        case .loading:
            ProgressView()
                .controlSize(.large)

        case .signedOut:
            LoginView()

        case .signedIn(let user):
            HomeView(user: user)
        }
    }
}

#Preview {
    ContentView()
        .environment(AuthSession(initialState: .signedOut))
}
