//
//  AccountMenu.swift
//  ommadawn
//
//  Menú desplegable de cuenta: saludo, apariencia y cerrar sesión.
//  Reemplaza la pestaña "Cuenta" del TabView.
//

import SwiftUI
import OmmadawnAPI

struct AccountMenu: View {
    let user: User
    @Environment(AuthSession.self) private var session
    @AppStorage("appearance") private var theme: AppTheme = .system

    private var displayName: String {
        if let name = user.full_name, !name.isEmpty { return name }
        return user.username
    }

    var body: some View {
        Menu {
            Section {
                Label(displayName, systemImage: "person.crop.circle")
                    .disabled(true)
            }

            Section {
                Picker("Apariencia", selection: $theme) {
                    Text("Sistema").tag(AppTheme.system)
                    Text("Claro").tag(AppTheme.light)
                    Text("Oscuro").tag(AppTheme.dark)
                }
            }

            Section {
                Button(role: .destructive) {
                    Task { await session.logOut() }
                } label: {
                    Label("Cerrar sesión", systemImage: "arrow.left.circle")
                }
            }
        } label: {
            Image(systemName: "person.crop.circle")
                .font(.system(size: 18))
        }
        .accessibilityLabel("Cuenta")
    }
}

#Preview {
    AccountMenu(user: User(
        id: 1,
        username: "rafatest",
        email: "rafa@example.com",
        full_name: "Rafa García",
        is_active: true,
        is_admin: false,
        created_at: .now
    ))
    .environment(AuthSession(initialState: .signedOut))
}
