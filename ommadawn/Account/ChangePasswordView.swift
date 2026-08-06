//
//  ChangePasswordView.swift
//  ommadawn
//
//  Cambiar la contraseña (o ponerla por primera vez, si la cuenta se creó
//  puramente por Google). Se presenta como hoja desde AccountProfileView.
//

import SwiftUI

struct ChangePasswordView: View {
    /// Si la cuenta no tiene contraseña propia (solo Google vinculado), el
    /// campo "contraseña actual" no tiene nada que pedir — no se muestra en
    /// vez de mostrarse vacío con una nota.
    let hasPassword: Bool

    @Environment(AuthSession.self) private var session
    @Environment(\.dismiss) private var dismiss

    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""

    @State private var isSubmitting = false
    @State private var errorMessage: String?

    // Igual que en RegisterView: mismos límites que la API (PasswordUpdate).
    private var newPasswordValid: Bool { (8...128).contains(newPassword.count) }
    private var passwordsMatch: Bool { newPassword == confirmPassword }
    private var isFormValid: Bool { newPasswordValid && passwordsMatch }

    var body: some View {
        NavigationStack {
            Form {
                if hasPassword {
                    Section {
                        SecureField("Contraseña actual", text: $currentPassword)
                            .textContentType(.password)
                    }
                } else {
                    Section {
                        Text("Tu cuenta entra solo con Google. Al guardar, esta contraseña se añade como una segunda forma de entrar.")
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    SecureField("Nueva contraseña", text: $newPassword)
                        .textContentType(.newPassword)
                    SecureField("Repite la nueva contraseña", text: $confirmPassword)
                        .textContentType(.newPassword)
                } footer: {
                    if !confirmPassword.isEmpty && !passwordsMatch {
                        Text("Las contraseñas no coinciden.")
                            .foregroundStyle(.red)
                    } else {
                        Text("Mínimo 8 caracteres.")
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage).foregroundStyle(.red)
                    }
                }

                Section {
                    Button {
                        Task { await submit() }
                    } label: {
                        if isSubmitting {
                            ProgressView().frame(maxWidth: .infinity)
                        } else {
                            Text("Guardar contraseña").frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(!isFormValid || isSubmitting)
                }
            }
            .navigationTitle(hasPassword ? "Cambiar contraseña" : "Agregar contraseña")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
            }
            .disabled(isSubmitting)
            .animation(.default, value: errorMessage)
        }
    }

    // MARK: - Acciones

    private func submit() async {
        guard isFormValid, !isSubmitting else { return }
        errorMessage = nil
        isSubmitting = true
        defer { isSubmitting = false }

        do {
            try await session.changePassword(
                currentPassword: hasPassword && !currentPassword.isEmpty ? currentPassword : nil,
                newPassword: newPassword
            )
            dismiss()
        } catch let error as PasswordChangeError {
            errorMessage = message(for: error)
        } catch {
            errorMessage = "Algo salió mal. Inténtalo de nuevo."
        }
    }

    private func message(for error: PasswordChangeError) -> String {
        switch error {
        case .wrongCurrentPassword:
            "La contraseña actual no es correcta."
        case .sessionExpired:
            "Tu sesión ha caducado. Vuelve a iniciar sesión."
        case .invalidData:
            "Revisa la nueva contraseña."
        case .passwordOnlyAccess:
            "Tu cuenta no tiene Google vinculado: la contraseña es tu única forma de entrar."
        case .unexpected(let statusCode):
            "Error del servidor (\(statusCode)). Inténtalo más tarde."
        case .network:
            "No se pudo conectar. Comprueba tu conexión."
        }
    }
}

#Preview {
    ChangePasswordView(hasPassword: true)
        .environment(AuthSession(initialState: .signedOut))
}

#Preview("Solo Google") {
    ChangePasswordView(hasPassword: false)
        .environment(AuthSession(initialState: .signedOut))
}
