//
//  RootTabView.swift
//  ommadawn
//
//  Shell de navegación de la app una vez hay sesión iniciada.
//
//  La cabecera ("Ommadawn" + menú de Cuenta) es común a toda la app y vive
//  aquí, por encima del TabView — no dentro de cada pestaña — para que se
//  mantenga fija al navegar. Las vistas raíz de cada pestaña (Discografía,
//  Tours) no ponen su propio título: la pestaña activa ya dice en qué
//  sección estás. Las vistas de detalle (p. ej. ReleaseDetailView) sí ponen
//  su propio navigationTitle, que aparece debajo de la cabecera como si
//  continuara el título de la app.
//

import SwiftUI
import OmmadawnAPI

struct RootTabView: View {
    let user: User

    var body: some View {
        VStack(spacing: 0) {
            AppHeaderBar(user: user)

            TabView {
                NavigationStack {
                    ReleaseListView()
                }
                .tabItem {
                    Label("Discografía", systemImage: "opticaldisc")
                }

                NavigationStack {
                    ToursPlaceholderView()
                }
                .tabItem {
                    Label("Tours", systemImage: "map")
                }
            }
        }
    }
}

/// Cabecera fija de la app: wordmark centrado, menú de Cuenta superpuesto a
/// la derecha. No es un `NavigationStack` de ninguna pestaña, así que no se
/// mueve al navegar dentro de ellas.
private struct AppHeaderBar: View {
    let user: User

    var body: some View {
        HStack {
            Spacer()
            Text("Ommadawn")
                .font(.custom("SnellRoundhand-Bold", size: 28))
                .foregroundStyle(Color("BrandGray"))
            Spacer()
        }
        .overlay(alignment: .trailing) {
            AccountMenu(user: user)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
    }
}

private struct ToursPlaceholderView: View {
    var body: some View {
        ContentUnavailableView(
            "Próximamente",
            systemImage: "map",
            description: Text("Giras, fechas y setlists llegarán en una fase futura.")
        )
        .toolbar(.hidden, for: .navigationBar)
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
