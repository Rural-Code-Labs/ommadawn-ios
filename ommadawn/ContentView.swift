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
    @AppStorage("appearance") private var theme: AppTheme = .system

    var body: some View {
        content
            .preferredColorScheme(theme.colorScheme)
            .overlay(alignment: .topTrailing) {
                ThemeSwitcher(theme: $theme)
                    .padding(.top, 4)
                    .padding(.trailing, 8)
            }
    }

    @ViewBuilder
    private var content: some View {
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
