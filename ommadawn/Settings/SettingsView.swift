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
    @AppStorage("appearance") private var theme: AppTheme = .system

    @State private var showingAdminUsers = false

    var body: some View {
        NavigationStack {
            List {
                Section("Apariencia") {
                    Picker("Color de la app", selection: $theme) {
                        ForEach(AppTheme.allCases, id: \.self) { option in
                            Label(option.label, systemImage: option.iconName)
                                .tag(option)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                    .onChange(of: theme) { _, newValue in
                        Task { try? await session.updateProfile(themePreference: newValue.apiValue) }
                    }
                }

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
        }
    }
}

#Preview {
    SettingsView(user: User(
        id: 1,
        username: "rafatest",
        email: "rafa@example.com",
        theme_preference: .system,
        is_active: true,
        is_admin: true,
        is_super_admin: true,
        created_at: .now
    ))
    .environment(AuthSession(initialState: .signedOut))
}
