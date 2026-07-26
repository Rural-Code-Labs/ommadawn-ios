//
//  AccountView.swift
//  ommadawn
//
//  Pestaña "Cuenta": saluda a la persona y permite cerrar sesión. Antes vivía
//  en HomeView (pantalla única de la app); ahora que hay una pestaña de
//  Discografía aparte, esta se queda solo con lo que le corresponde.
//

import SwiftUI
import OmmadawnAPI

struct AccountView: View {
    let user: User
    @Environment(AuthSession.self) private var session
    @AppStorage("appearance") private var theme: AppTheme = .system

    /// Nombre a mostrar: el `full_name` si lo hay, si no el `username`.
    private var displayName: String {
        if let name = user.full_name, !name.isEmpty { return name }
        return user.username
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 6) {
                BrandMark(size: 88)
                Text("Hola, \(displayName)")
                    .font(.title3.weight(.semibold))
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Apariencia")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                AppearancePicker(theme: $theme)
            }

            Spacer()

            Button {
                Task { await session.logOut() }
            } label: {
                Text("Cerrar sesión")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 32)
        .frame(maxWidth: 420)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("Cuenta")
    }
}

#Preview {
    NavigationStack {
        AccountView(user: User(
            id: 1,
            username: "rafatest",
            email: "rafa@example.com",
            is_active: true,
            is_admin: false,
            created_at: .now
        ))
    }
    .environment(AuthSession(initialState: .signedOut))
}
