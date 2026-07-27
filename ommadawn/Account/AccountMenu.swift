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
    @AppStorage("appearance") private var theme: AppTheme = .system

    @State private var showingProfile = false
    @State private var showingAdminUsers = false

    var body: some View {
        Menu {
            Section {
                Button {
                    showingProfile = true
                } label: {
                    Label(user.displayName, systemImage: "person.crop.circle")
                }
            }

            Section {
                Picker("Apariencia", selection: $theme) {
                    Text("Sistema").tag(AppTheme.system)
                    Text("Claro").tag(AppTheme.light)
                    Text("Oscuro").tag(AppTheme.dark)
                }
            }

            if user.is_super_admin {
                Section {
                    Button {
                        showingAdminUsers = true
                    } label: {
                        Label("Administrar usuarios", systemImage: "person.2.badge.gearshape")
                    }
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
            AccountAvatarView(user: user, size: 18)
        }
        .accessibilityLabel("Cuenta")
        .sheet(isPresented: $showingProfile) {
            AccountProfileView()
        }
        .sheet(isPresented: $showingAdminUsers) {
            AdminUsersView()
        }
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
        is_super_admin: false,
        created_at: .now
    ))
    .environment(AuthSession(initialState: .signedOut))
}
