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

/// Cabecera fija de la app: wordmark centrado, avatar de cuenta a la
/// izquierda y engranaje de ajustes a la derecha. No es un NavigationStack
/// de ninguna pestaña, así que no se mueve al navegar dentro de ellas.
private struct AppHeaderBar: View {
    let user: User
    @State private var showingSettings = false

    var body: some View {
        HStack {
            Spacer()
            Text("Ommadawn")
                .font(.custom("Didot-Italic", size: 32))
                .tracking(0.5)
                .foregroundStyle(Color("BrandGray"))
            Spacer()
        }
        .overlay(alignment: .leading) {
            AccountMenu(user: user)
        }
        .overlay(alignment: .trailing) {
            if user.is_admin {
                Button {
                    showingSettings = true
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 20))
                        .foregroundStyle(.primary)
                }
                .buttonStyle(.plain)
                .padding()
                .accessibilityLabel("Ajustes")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
        .sheet(isPresented: $showingSettings) {
            SettingsView(user: user)
        }
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
        username_is_default: false,
        email: "rafa@example.com",
        theme_preference: .system,
        has_google: false,
        has_password: true,
        is_active: true,
        is_admin: false,
        is_super_admin: false,
        created_at: .now
    ))
    .environment(AuthSession(initialState: .signedOut))
}
