//
//  AccountMenu.swift
//  ommadawn
//
//  Menú desplegable de cuenta: nombre (abre el perfil), apariencia y cerrar
//  sesión. Reemplaza la pestaña "Cuenta" del TabView. Si el usuario es
//  superadministrador, añade acceso a la gestión de administradores.
//

import SwiftUI
import OmmadawnAPI

struct AccountMenu: View {
    let user: User
    @Environment(AuthSession.self) private var session

    @State private var showingProfile = false

    var body: some View {
        Menu {
            Section {
                Button {
                    showingProfile = true
                } label: {
                    Label("Editar perfil", systemImage: "person.crop.circle")
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
            AccountAvatarView(user: user, size: 32)
        }
        .accessibilityLabel("Cuenta")
        .sheet(isPresented: $showingProfile) {
            AccountProfileView()
        }
    }
}

#Preview {
    AccountMenu(user: User(
        id: 1,
        username: "rafatest",
        email: "rafa@example.com",
        full_name: "Rafa García",
        theme_preference: .system,
        is_active: true,
        is_admin: false,
        is_super_admin: false,
        created_at: .now
    ))
    .environment(AuthSession(initialState: .signedOut))
}
