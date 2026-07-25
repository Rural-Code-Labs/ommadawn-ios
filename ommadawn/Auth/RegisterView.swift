//
//  RegisterView.swift
//  ommadawn
//
//  Alta de cuenta. Se presenta como hoja (sheet) desde el login. Al registrar
//  con éxito, AuthSession hace login automático y el enrutado por estado saca
//  de aquí solo.
//

import SwiftUI

struct RegisterView: View {
    @Environment(AuthSession.self) private var session
    @Environment(\.dismiss) private var dismiss

    @State private var username = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""

    @State private var isSubmitting = false
    @State private var errorMessage: String?

    // Validación en cliente, con los mismos límites que la API (UserCreate).
    // Evita 422 innecesarios: solo mandamos si el formulario ya es plausible.
    private var usernameValid: Bool { (3...50).contains(username.count) }
    private var emailValid: Bool { email.contains("@") && email.contains(".") }
    private var passwordValid: Bool { (8...128).contains(password.count) }
    private var passwordsMatch: Bool { password == confirmPassword }
    private var isFormValid: Bool {
        usernameValid && emailValid && passwordValid && passwordsMatch
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Usuario", text: $username)
                        .textContentType(.username)
                        .autocorrectionDisabled()
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        #endif
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .autocorrectionDisabled()
                        #if os(iOS)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        #endif
                } footer: {
                    Text("El usuario debe tener entre 3 y 50 caracteres.")
                }

                Section {
                    SecureField("Contraseña", text: $password)
                        .textContentType(.newPassword)
                    SecureField("Repite la contraseña", text: $confirmPassword)
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
                            Text("Crear cuenta").frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(!isFormValid || isSubmitting)
                }
            }
            .navigationTitle("Crear cuenta")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
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
            try await session.register(username: username, email: email, password: password)
            // Éxito: la sesión pasa a signedIn y ContentView enruta a la app;
            // esta hoja se cierra sola al desmontarse el login.
        } catch let error as RegisterError {
            errorMessage = message(for: error)
        } catch {
            errorMessage = "Algo salió mal. Inténtalo de nuevo."
        }
    }

    private func message(for error: RegisterError) -> String {
        switch error {
        case .alreadyTaken:
            "Ese usuario o email ya está en uso."
        case .invalidData:
            "Revisa los datos introducidos."
        case .registeredButLoginFailed:
            "Cuenta creada. Vuelve e inicia sesión para entrar."
        case .unexpected(let statusCode):
            "Error del servidor (\(statusCode)). Inténtalo más tarde."
        case .network:
            "No se pudo conectar. Comprueba tu conexión."
        }
    }
}

#Preview {
    RegisterView()
        .environment(AuthSession(initialState: .signedOut))
}
