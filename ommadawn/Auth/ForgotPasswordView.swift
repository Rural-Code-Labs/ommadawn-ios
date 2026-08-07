//
//  ForgotPasswordView.swift
//  ommadawn
//
//  Recuperar contraseña: código de 6 dígitos por email, igual que
//  VerifyEmailView, pero sin sesión (el usuario está deslogueado — es justo
//  el caso que resuelve esto). Si el código y la contraseña nueva son
//  correctos, la API loguea directamente: no hay que volver a la pantalla
//  de login para entrar a mano.
//
//  La API responde igual (204) exista o no la cuenta con `usernameOrEmail`,
//  a propósito, para no revelar qué cuentas están registradas — los textos
//  de esta pantalla mantienen ese mismo cuidado ("si existe una cuenta...",
//  nunca "hemos enviado" a secas).
//

import SwiftUI

struct ForgotPasswordView: View {
    @Environment(AuthSession.self) private var session
    @Environment(\.dismiss) private var dismiss

    @State private var usernameOrEmail = ""
    @State private var hasRequestedCode = false
    @State private var code = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""

    @State private var isSendingCode = false
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    private var identifierValid: Bool { !usernameOrEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    private var codeValid: Bool { code.count == 6 }
    private var newPasswordValid: Bool { (8...128).contains(newPassword.count) }
    private var passwordsMatch: Bool { newPassword == confirmPassword }
    private var isFormValid: Bool { codeValid && newPasswordValid && passwordsMatch }

    var body: some View {
        NavigationStack {
            Form {
                if !hasRequestedCode {
                    Section {
                        TextField("Usuario o email", text: $usernameOrEmail)
                            .textContentType(.username)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                    } footer: {
                        Text("Si existe una cuenta con esos datos, te enviaremos un código de 6 dígitos por email. Caduca en 2 horas.")
                    }
                } else {
                    Section {
                        Text("Si existe una cuenta con esos datos, te hemos enviado un código por email.")
                            .foregroundStyle(.secondary)
                    }

                    Section {
                        TextField("Código", text: $code)
                            .keyboardType(.numberPad)
                            .textContentType(.oneTimeCode)
                            .onChange(of: code) { _, newValue in
                                code = String(newValue.filter(\.isNumber).prefix(6))
                            }
                        SecureField("Contraseña nueva", text: $newPassword)
                            .textContentType(.newPassword)
                        SecureField("Repite la contraseña nueva", text: $confirmPassword)
                            .textContentType(.newPassword)
                    } footer: {
                        if !confirmPassword.isEmpty && !passwordsMatch {
                            Text("Las contraseñas no coinciden.")
                                .foregroundStyle(.red)
                        } else {
                            Text("Mínimo 8 caracteres.")
                        }
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage).foregroundStyle(.red)
                    }
                }

                Section {
                    if hasRequestedCode {
                        Button {
                            Task { await confirm() }
                        } label: {
                            if isSubmitting {
                                ProgressView().frame(maxWidth: .infinity)
                            } else {
                                Text("Restablecer contraseña").frame(maxWidth: .infinity)
                            }
                        }
                        .disabled(!isFormValid || isSubmitting)

                        Button {
                            Task { await requestCode() }
                        } label: {
                            Text("Reenviar código").frame(maxWidth: .infinity)
                        }
                        .disabled(isSendingCode || isSubmitting)
                    } else {
                        Button {
                            Task { await requestCode() }
                        } label: {
                            if isSendingCode {
                                ProgressView().frame(maxWidth: .infinity)
                            } else {
                                Text("Enviar código").frame(maxWidth: .infinity)
                            }
                        }
                        .disabled(!identifierValid || isSendingCode)
                    }
                }
            }
            .navigationTitle("Recuperar contraseña")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
            }
            .disabled(isSubmitting)
            .animation(.default, value: errorMessage)
            .animation(.default, value: hasRequestedCode)
        }
    }

    // MARK: - Acciones

    private func requestCode() async {
        guard identifierValid, !isSendingCode else { return }
        errorMessage = nil
        isSendingCode = true
        defer { isSendingCode = false }
        do {
            try await session.requestPasswordReset(usernameOrEmail: usernameOrEmail)
            hasRequestedCode = true
        } catch let error as PasswordResetError {
            errorMessage = message(for: error)
        } catch {
            errorMessage = "No se pudo enviar la solicitud. Inténtalo de nuevo."
        }
    }

    private func confirm() async {
        guard isFormValid, !isSubmitting else { return }
        errorMessage = nil
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            try await session.confirmPasswordReset(
                usernameOrEmail: usernameOrEmail,
                code: code,
                newPassword: newPassword
            )
            // Éxito: la sesión pasa a signedIn y ContentView enruta a la
            // app; esta hoja se cierra sola al desmontarse el login.
        } catch let error as PasswordResetError {
            errorMessage = message(for: error)
        } catch {
            errorMessage = "Algo salió mal. Inténtalo de nuevo."
        }
    }

    private func message(for error: PasswordResetError) -> String {
        switch error {
        case .invalidCode:
            "Ese código no es correcto o ha caducado."
        case .tooManyAttempts:
            "Demasiados intentos. Inténtalo de nuevo más tarde."
        case .invalidData:
            "Revisa el código y la contraseña nueva."
        case .unexpected(let statusCode):
            "Error del servidor (\(statusCode)). Inténtalo más tarde."
        case .network:
            "No se pudo conectar. Comprueba tu conexión."
        }
    }
}

#Preview {
    ForgotPasswordView()
        .environment(AuthSession(initialState: .signedOut))
}
