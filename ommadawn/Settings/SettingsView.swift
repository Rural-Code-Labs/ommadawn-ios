//
//  SettingsView.swift
//  ommadawn
//
//  Ajustes de la app: apariencia (sincronizada con el campo theme_preference
//  del servidor) y opciones según el rol del usuario (administrar usuarios,
//  si es superadministrador).
//

import SwiftUI
import OmmadawnAPI

struct SettingsView: View {
    let user: User
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthSession.self) private var session

    @State private var showingAdminUsers = false
    @State private var pendingEnvironment: APIEnvironment?

    var body: some View {
        NavigationStack {
            List {
                if user.is_super_admin {
                    Section("Administración") {
                        Button {
                            showingAdminUsers = true
                        } label: {
                            Label("Administrar usuarios", systemImage: "person.2.badge.gearshape")
                                .foregroundStyle(.primary)
                        }
                    }
                }

                Section {
                    Picker("API", selection: Binding(
                        get: { session.environment },
                        set: { pendingEnvironment = $0 }
                    )) {
                        ForEach(APIEnvironment.allCases, id: \.self) { env in
                            Text(env.displayName).tag(env)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                } header: {
                    Text("Entorno")
                } footer: {
                    Text("Cambiar el entorno cierra la sesión actual.")
                }
            }
            .navigationTitle("Ajustes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { dismiss() }
                }
            }
            .sheet(isPresented: $showingAdminUsers) {
                AdminUsersView()
            }
            .alert("Cambiar entorno", isPresented: Binding(
                get: { pendingEnvironment != nil },
                set: { if !$0 { pendingEnvironment = nil } }
            )) {
                Button("Cambiar y cerrar sesión", role: .destructive) {
                    if let env = pendingEnvironment {
                        Task { await session.switchEnvironment(env) }
                    }
                    pendingEnvironment = nil
                    dismiss()
                }
                Button("Cancelar", role: .cancel) { pendingEnvironment = nil }
            } message: {
                if let env = pendingEnvironment {
                    Text("Se cambiará a \"\(env.displayName)\" y se cerrará la sesión actual.")
                }
            }
        }
    }
}

#Preview {
    SettingsView(user: User(
        id: 1,
        username: "rafatest",
        username_is_default: false,
        email: "rafa@example.com",
        email_verified: true,
        theme_preference: .system,
        has_google: false,
        has_password: true,
        is_active: true,
        is_admin: true,
        is_super_admin: true,
        created_at: .now
    ))
    .environment(AuthSession(initialState: .signedOut))
}
