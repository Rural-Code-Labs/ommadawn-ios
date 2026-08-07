//
//  AdminUsersView.swift
//  ommadawn
//
//  Lista de usuarios con un interruptor para promover/degradar a
//  administrador. Solo la abre AccountMenu cuando `user.is_super_admin`
//  (la API también lo exige del lado del servidor: esto es solo UI).
//
//  No se puede tocar `is_super_admin` desde aquí — la API tampoco lo
//  permite, nombrar un superadmin sigue siendo solo por base de datos.
//

import SwiftUI
import OmmadawnAPI

struct AdminUsersView: View {
    @Environment(AuthSession.self) private var session
    @Environment(\.dismiss) private var dismiss

    @State private var users: [User] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var pendingUserID: Int?

    private var store: AdminStore { AdminStore(client: session.client) }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Administrar usuarios")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cerrar") { dismiss() }
                    }
                }
                .task { await load() }
                .refreshable { await load() }
                .alert("Algo salió mal", isPresented: Binding(
                    get: { errorMessage != nil && !users.isEmpty },
                    set: { if !$0 { errorMessage = nil } }
                )) {
                    Button("Vale", role: .cancel) {}
                } message: {
                    Text(errorMessage ?? "")
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        if isLoading && users.isEmpty {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if users.isEmpty, let errorMessage {
            ContentUnavailableView {
                Label("No se pudo cargar", systemImage: "wifi.slash")
            } description: {
                Text(errorMessage)
            } actions: {
                Button("Reintentar") { Task { await load() } }
            }
        } else {
            List(users, id: \.id) { user in
                row(for: user)
            }
            .listStyle(.plain)
        }
    }

    private func row(for user: User) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(user.displayName)
                    .font(.body)
                Text(user.email)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if user.is_super_admin {
                Text("Superadmin")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if pendingUserID == user.id {
                ProgressView()
            } else {
                Toggle("Admin", isOn: Binding(
                    get: { user.is_admin },
                    set: { newValue in Task { await setAdmin(user: user, isAdmin: newValue) } }
                ))
                .labelsHidden()
            }
        }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            users = try await store.listUsers()
                .sorted { $0.username.localizedStandardCompare($1.username) == .orderedAscending }
        } catch let error as AdminError {
            errorMessage = message(for: error)
        } catch {
            errorMessage = "Comprueba tu conexión e inténtalo de nuevo."
        }
    }

    private func setAdmin(user: User, isAdmin: Bool) async {
        pendingUserID = user.id
        defer { pendingUserID = nil }
        do {
            let updated = try await store.setAdmin(userID: user.id, isAdmin: isAdmin)
            if let index = users.firstIndex(where: { $0.id == updated.id }) {
                users[index] = updated
            }
        } catch let error as AdminError {
            errorMessage = message(for: error)
        } catch {
            errorMessage = "No se pudo actualizar. Inténtalo de nuevo."
        }
    }

    private func message(for error: AdminError) -> String {
        switch error {
        case .forbidden:
            "No tienes permisos para gestionar usuarios."
        case .notFound:
            "El usuario ya no existe."
        case .unexpected(let statusCode):
            "Error del servidor (\(statusCode)). Inténtalo más tarde."
        case .network:
            "No se pudo conectar. Comprueba tu conexión."
        }
    }
}

#Preview {
    AdminUsersView()
        .environment(AuthSession(initialState: .signedIn(User(
            id: 1,
            username: "discotest2",
            username_is_default: false,
            email: "discotest2@example.com",
            email_verified: true,
            theme_preference: .system,
            has_google: false,
            has_password: true,
            is_active: true,
            is_admin: true,
            is_super_admin: true,
            created_at: .now
        ))))
}
