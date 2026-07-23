//
//  LoginView.swift
//  ommadawn
//
//  Pantalla de inicio de sesión.
//
//  ⚠️ De momento es SOLO UI: no hay capa de red ni autenticación real.
//  El botón "Entrar" simula una espera y no habla con la API. La lógica
//  de verdad (tokens, Keychain, refresh) llega en la Fase 3.
//

import SwiftUI

struct LoginView: View {
    // El estado del formulario es LOCAL a la vista → @State.
    // Lo que el usuario teclea no le interesa a nadie más todavía.
    @State private var email = ""
    @State private var password = ""

    // UX: alternar entre ocultar/mostrar la contraseña.
    @State private var isPasswordVisible = false

    // Simula la espera de una petición de red (placeholder de la Fase 3).
    @State private var isSubmitting = false

    // Validación mínima en cliente para habilitar el botón.
    // No valida "de verdad" el email: solo evita mandar formularios vacíos.
    private var isFormValid: Bool {
        email.contains("@") && !password.isEmpty
    }

    var body: some View {
        VStack(spacing: 32) {
            header

            VStack(spacing: 16) {
                emailField
                passwordField
            }

            loginButton

            registerLink
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: 420) // en iPad/Mac no queremos campos gigantes
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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

    private var emailField: some View {
        TextField("Email", text: $email)
            .textContentType(.emailAddress)
            .autocorrectionDisabled()
            #if os(iOS)
            .keyboardType(.emailAddress)
            .textInputAutocapitalization(.never)
            #endif
            .textFieldStyle(.roundedBorder)
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
                // TODO: Fase 3 — navegar a la pantalla de registro.
            }
        }
        .font(.footnote)
    }

    // MARK: - Acciones

    /// Placeholder: simula la latencia de un login real.
    /// En la Fase 3 esto llamará a `POST /api/v1/auth/login` y guardará
    /// los tokens en el Keychain.
    private func submit() async {
        isSubmitting = true
        defer { isSubmitting = false }
        try? await Task.sleep(for: .seconds(1))
        // De momento no hace nada más.
    }
}

#Preview {
    LoginView()
}
