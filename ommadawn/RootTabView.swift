//
//  RootTabView.swift
//  ommadawn
//
//  Shell de navegación de la app una vez hay sesión iniciada. Dos pestañas
//  hoy (Discografía, Cuenta); Conciertos y Libros se añadirán aquí en sus
//  fases correspondientes.
//

import SwiftUI
import OmmadawnAPI

struct RootTabView: View {
    let user: User

    var body: some View {
        TabView {
            Tab("Discografía", systemImage: "opticaldisc") {
                NavigationStack {
                    ReleaseListView()
                }
            }
            Tab("Cuenta", systemImage: "person.crop.circle") {
                NavigationStack {
                    AccountView(user: user)
                }
            }
        }
    }
}

#Preview {
    RootTabView(user: User(
        id: 1,
        username: "rafatest",
        email: "rafa@example.com",
        is_active: true,
        is_admin: false,
        created_at: .now
    ))
    .environment(AuthSession(initialState: .signedOut))
}
