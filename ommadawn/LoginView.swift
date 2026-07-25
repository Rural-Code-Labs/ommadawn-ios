//
//  LoginView.swift
//  ommadawn
//
//  Pantalla de inicio de sesión. Recoge credenciales y delega en
//  `AuthSession` el trabajo real (red, tokens, Keychain).
//
//  Al iniciar sesión con éxito, `AuthSession` cambia de estado y la vista
//  raíz (ContentView) enruta fuera de aquí sola: esta pantalla no navega.
//

import SwiftUI

struct LoginView: View {
    @Environment(AuthSession.self) private var session

    // Estado del formulario: local a la vista.
    // La API acepta username O email en el mismo campo (`username_or_email`).
    @State private var usernameOrEmail = ""
    @State private var password = ""
    @State private var isPasswordVisible = false

    @State private var isSubmitting = false
    /// Mensaje de error a mostrar bajo el formulario (nil = sin error).
    @State private var errorMessage: String?

    /// Solo evita enviar formularios vacíos. La validación de verdad
    /// (credenciales correctas) la hace el servidor.
    private var isFormValid: Bool {
        !usernameOrEmail.isEmpty && !password.isEmpty
    }

    var body: some View {
        VStack(spacing: 32) {
            header

            VStack(spacing: 16) {
                identifierField
                passwordField
                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .transition(.opacity)
                }
            }

            loginButton

            registerLink
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: 420) // en iPad/Mac no queremos campos gigantes
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .disabled(isSubmitting)
        .animation(.default, value: errorMessage)
    }

    // MARK: - Secciones

    private var header: some View {
        VStack(spacing: 8) {
            Image(systemName: "waveform")
                .font(.system(size: 56))
                .foregroundStyle(.tint)
                .symbolEffect(.pulse, isActive: isSubmitting)

            Text("ommadawn")
                .font(.largeTitle.bold())

            Text("El catálogo de Mike Oldfield")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var identifierField: some View {
        TextField("Usuario o email", text: $usernameOrEmail)
            .textContentType(.username)
            .autocorrectionDisabled()
            #if os(iOS)
            .textInputAutocapitalization(.never)
            #endif
            .textFieldStyle(.roundedBorder)
            .onChange(of: usernameOrEmail) { errorMessage = nil }
    }

    private var passwordField: some View {
        HStack {
            Group {
                if isPasswordVisible {
                    TextField("Contraseña", text: $password)
                } else {
                    SecureField("Contraseña", text: $password)
                }
            }
            .textContentType(.password)
            .autocorrectionDisabled()
            #if os(iOS)
            .textInputAutocapitalization(.never)
            #endif
            .onChange(of: password) { errorMessage = nil }
            .onSubmit { Task { await submit() } }

            Button {
                isPasswordVisible.toggle()
            } label: {
                Image(systemName: isPasswordVisible ? "eye.slash" : "eye")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isPasswordVisible ? "Ocultar contraseña" : "Mostrar contraseña")
        }
        .padding(8)
        .background(.quaternary, in: .rect(cornerRadius: 8))
    }

    private var loginButton: some View {
        Button {
            Task { await submit() }
        } label: {
            if isSubmitting {
                ProgressView()
                    .frame(maxWidth: .infinity)
            } else {
                Text("Entrar")
                    .frame(maxWidth: .infinity)
            }
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(!isFormValid || isSubmitting)
    }

    private var registerLink: some View {
        HStack(spacing: 4) {
            Text("¿No tienes cuenta?")
                .foregroundStyle(.secondary)
            Button("Crear una") {
                // TODO: paso 3.5 — navegar a la pantalla de registro.
            }
        }
        .font(.footnote)
    }

    // MARK: - Acciones

    /// Inicia sesión a través de `AuthSession`. En caso de éxito no hay que
    /// hacer nada más: el enrutado por estado nos saca de esta pantalla.
    private func submit() async {
        guard isFormValid, !isSubmitting else { return }
        errorMessage = nil
        isSubmitting = true
        defer { isSubmitting = false }

        do {
            try await session.logIn(usernameOrEmail: usernameOrEmail, password: password)
        } catch let error as LoginError {
            errorMessage = message(for: error)
        } catch {
            errorMessage = "Algo salió mal. Inténtalo de nuevo."
        }
    }

    /// Traduce el error del modelo a un texto para la persona usuaria.
    /// (La UI es la dueña de estas cadenas, no `AuthSession`.)
    private func message(for error: LoginError) -> String {
        switch error {
        case .invalidCredentials:
            "Usuario o contraseña incorrectos."
        case .accountDisabled:
            "Tu cuenta está desactivada."
        case .invalidData:
            "Revisa los datos introducidos."
        case .unexpected(let statusCode):
            "Error del servidor (\(statusCode)). Inténtalo más tarde."
        case .network:
            "No se pudo conectar. Comprueba tu conexión."
        }
    }
}

#Preview {
    LoginView()
        .environment(AuthSession(initialState: .signedOut))
}
