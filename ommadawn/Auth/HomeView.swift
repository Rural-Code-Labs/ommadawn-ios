//
//  HomeView.swift
//  ommadawn
//
//  Placeholder de "sesión iniciada". Las pantallas reales (discografía,
//  conciertos…) llegan en fases posteriores; por ahora solo confirma quién
//  está dentro y permite cerrar sesión.
//

import SwiftUI
import OmmadawnAPI

struct HomeView: View {
    let user: User
    @Environment(AuthSession.self) private var session

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 48))
                .foregroundStyle(.tint)

            Text("¡Hola, \(user.username)!")
                .font(.title2.bold())
            Text(user.email)
                .foregroundStyle(.secondary)

            Button("Cerrar sesión") {
                Task { await session.logOut() }
            }
            .buttonStyle(.bordered)
            .padding(.top, 8)
        }
        .padding()
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
