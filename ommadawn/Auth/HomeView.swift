//
//  HomeView.swift
//  ommadawn
//
//  Pantalla de "sesión iniciada". Las secciones reales (discografía,
//  conciertos…) llegan en fases posteriores; por ahora es un placeholder
//  con la identidad de la app: saluda a la persona y permite cerrar sesión.
//

import SwiftUI
import OmmadawnAPI

struct HomeView: View {
    let user: User
    @Environment(AuthSession.self) private var session

    /// Nombre a mostrar: el `full_name` si lo hay, si no el `username`.
    private var displayName: String {
        if let name = user.full_name, !name.isEmpty { return name }
        return user.username
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Masthead con la misma marca que el login.
            VStack(spacing: 6) {
                BrandMark(size: 88)
                Text("Ommadawn")
                    .font(.custom("SnellRoundhand-Bold", size: 30))
                    .foregroundStyle(Color("BrandGray"))
            }

            VStack(spacing: 6) {
                Text("Hola, \(displayName)")
                    .font(.title3.weight(.semibold))
                Text("Tu catálogo de Mike Oldfield llegará muy pronto.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
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
    }
}

#Preview {
    HomeView(user: User(
        id: 1,
        username: "rafatest",
        email: "rafa@example.com",
        is_active: true,
        is_admin: false,
        created_at: .now
    ))
    .environment(AuthSession(initialState: .signedOut))
}
