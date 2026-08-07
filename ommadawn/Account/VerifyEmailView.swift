//
//  VerifyEmailView.swift
//  ommadawn
//
//  Verificación de email por código: pide un código de 6 dígitos por email
//  y lo confirma. "Soft" — no bloquea nada de la app, es solo un aviso en
//  el perfil hasta que se verifica. Se presenta como hoja desde
//  AccountProfileView.
//

import SwiftUI

struct VerifyEmailView: View {
    @Environment(AuthSession.self) private var session
    @Environment(\.dismiss) private var dismiss

    /// Antes de pedir el primer código, solo hay un botón "Enviar código" —
    /// no se manda nada automáticamente al abrir la hoja, porque cada envío
    /// invalida el código anterior: si el usuario ya tiene uno sin leer en
    /// el correo, reabrir esta hoja por accidente no debería dejárselo
    /// inservible.
    @State private var hasRequestedCode = false
    @State private var code = ""
    @State private var isSubmitting = false
    @State private var isSendingCode = false
    @State private var errorMessage: String?
    @State private var infoMessage: String?

    private var codeValid: Bool { code.count == 6 }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Te enviamos un código de 6 dígitos a tu email para confirmar que es tuyo. Caduca en 2 horas.")
                        .foregroundStyle(.secondary)
                }

                if hasRequestedCode {
                    Section {
                        TextField("Código", text: $code)
                            .keyboardType(.numberPad)
                            .textContentType(.oneTimeCode)
                            .onChange(of: code) { _, newValue in
                                code = String(newValue.filter(\.isNumber).prefix(6))
                            }
                    } footer: {
                        if let infoMessage {
                            Text(infoMessage)
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
                                Text("Verificar").frame(maxWidth: .infinity)
                            }
                        }
                        .disabled(!codeValid || isSubmitting)

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
                        .disabled(isSendingCode)
                    }
                }
            }
            .navigationTitle("Verificar email")
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
        errorMessage = nil
        infoMessage = nil
        isSendingCode = true
        defer { isSendingCode = false }
        do {
            try await session.requestEmailVerification()
            hasRequestedCode = true
            infoMessage = "Código enviado."
        } catch let error as EmailVerificationError {
            errorMessage = message(for: error)
        } catch {
            errorMessage = "No se pudo enviar el código. Inténtalo de nuevo."
        }
    }

    private func confirm() async {
        guard codeValid, !isSubmitting else { return }
        errorMessage = nil
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            try await session.confirmEmailVerification(code: code)
            dismiss()
        } catch let error as EmailVerificationError {
            errorMessage = message(for: error)
        } catch {
            errorMessage = "Algo salió mal. Inténtalo de nuevo."
        }
    }

    private func message(for error: EmailVerificationError) -> String {
        switch error {
        case .sessionExpired:
            "Tu sesión ha caducado. Vuelve a iniciar sesión."
        case .invalidCode:
            "Ese código no es correcto o ha caducado."
        case .tooManyAttempts:
            "Demasiados intentos. Inténtalo de nuevo más tarde."
        case .invalidData:
            "El código debe tener 6 dígitos."
        case .unexpected(let statusCode):
            "Error del servidor (\(statusCode)). Inténtalo más tarde."
        case .network:
            "No se pudo conectar. Comprueba tu conexión."
        }
    }
}

#Preview {
    VerifyEmailView()
        .environment(AuthSession(initialState: .signedOut))
}
