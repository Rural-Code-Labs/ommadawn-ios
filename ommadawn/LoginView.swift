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
//  Usuario/email y contraseña van en una única tarjeta (con separador) en
//  vez de dos cajas sueltas, y el botón principal usa `BrandGray` (el mismo
//  gris del logo y el wordmark) en vez del azul de sistema, para que el
//  color de marca aparezca también en la acción principal.
//

import SwiftUI
import OmmadawnAPI
import GoogleSignIn

struct LoginView: View {
    @Environment(AuthSession.self) private var session
    @AppStorage("appearance") private var theme: AppTheme = .system

    // Estado del formulario: local a la vista.
    // La API acepta username O email en el mismo campo (`username_or_email`).
    @State private var usernameOrEmail = ""
    @State private var password = ""
    @State private var isPasswordVisible = false

    @State private var isSubmitting = false
    /// Mensaje de error a mostrar bajo el formulario (nil = sin error).
    @State private var errorMessage: String?
    /// Controla la presentación de la hoja de registro.
    @State private var showingRegister = false
    /// Controla la presentación del panel "Acerca de".
    @State private var showingAbout = false
    @State private var showingEnvironmentPicker = false

    /// Solo evita enviar formularios vacíos. La validación de verdad
    /// (credenciales correctas) la hace el servidor.
    private var isFormValid: Bool {
        !usernameOrEmail.isEmpty && !password.isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                header

                VStack(spacing: 12) {
                    credentialsCard
                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .transition(.opacity)
                    }
                }

                loginButton

                orDivider

                googleSignInButton

                registerLink

                environmentBadge
            }
            .padding(.horizontal, 24)
            .padding(.top, 48)
            .padding(.bottom, 24)
            .frame(maxWidth: 420) // en iPad/Mac no queremos campos gigantes
            .frame(maxWidth: .infinity)
        }
        .overlay(alignment: .topTrailing) {
            HStack(spacing: 4) {
                appearanceButton
                infoButton
            }
        }
        .disabled(isSubmitting)
        .animation(.default, value: errorMessage)
    }

    // MARK: - Secciones

    /// Cambio rápido de apariencia (Sistema → Claro → Oscuro → Sistema).
    /// El selector completo con las tres opciones vive en el menú de Cuenta
    /// una vez logueado; aquí es solo un atajo de un toque.
    private var appearanceButton: some View {
        Button {
            theme = theme.next
        } label: {
            Image(systemName: theme.iconName)
                .font(.system(size: 20))
                .foregroundStyle(.primary)
        }
        .buttonStyle(.plain)
        .padding()
        .accessibilityLabel("Cambiar apariencia")
    }

    /// Abre "Acerca de". El mismo panel se reutilizará más adelante desde
    /// el menú de Cuenta (botón "Acerca de"), ya logueado.
    private var infoButton: some View {
        Button {
            showingAbout = true
        } label: {
            Image(systemName: "info.circle")
                .font(.system(size: 20))
                .foregroundStyle(.primary)
        }
        .buttonStyle(.plain)
        .padding()
        .accessibilityLabel("Acerca de")
        .sheet(isPresented: $showingAbout) {
            AboutView()
        }
    }

    private var header: some View {
        VStack(spacing: 6) {
            BrandMark(size: 110)
                .opacity(isSubmitting ? 0.4 : 1)

            Text("Ommadawn")
                .font(.custom("Didot-Italic", size: 34))
                .tracking(1)
                .foregroundStyle(Color("BrandGray"))

            Text("El universo sonoro de Mike Oldfield")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    /// Usuario/email y contraseña en una única tarjeta, con un separador
    /// entre ambos en vez de dos cajas sueltas — se lee como un solo bloque
    /// de "credenciales", no dos campos independientes.
    private var credentialsCard: some View {
        VStack(spacing: 0) {
            usernameField
            Divider().padding(.leading, 48)
            passwordField
        }
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var usernameField: some View {
        HStack(spacing: 12) {
            Image(systemName: "person")
                .foregroundStyle(.secondary)
                .frame(width: 20)
            TextField("Usuario o email", text: $usernameOrEmail)
                .textContentType(.username)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .onChange(of: usernameOrEmail) { errorMessage = nil }
        }
        .padding(16)
    }

    private var passwordField: some View {
        HStack(spacing: 12) {
            Image(systemName: "lock")
                .foregroundStyle(.secondary)
                .frame(width: 20)
            Group {
                if isPasswordVisible {
                    TextField("Contraseña", text: $password)
                } else {
                    SecureField("Contraseña", text: $password)
                }
            }
            .textContentType(.password)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
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
        .padding(16)
    }

    /// Capsule en BrandGray en vez de `.borderedProminent` (azul de
    /// sistema) — la acción principal lleva el color de la marca.
    private var loginButton: some View {
        Button {
            Task { await submit() }
        } label: {
            if isSubmitting {
                ProgressView()
                    .tint(.white)
                    .frame(maxWidth: .infinity)
            } else {
                Text("Entrar")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
            }
        }
        .foregroundStyle(.white)
        .padding(.vertical, 14)
        .background(Color("BrandGray"), in: .capsule)
        .buttonStyle(.plain)
        .opacity(isFormValid ? 1 : 0.4)
        .disabled(!isFormValid || isSubmitting)
    }

    private var orDivider: some View {
        HStack(spacing: 8) {
            Rectangle().frame(height: 1).foregroundStyle(.quaternary)
            Text("o")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Rectangle().frame(height: 1).foregroundStyle(.quaternary)
        }
    }

    /// Blanco con la "G" a color (sin reproducir el logotipo exacto, solo su
    /// paleta).
    private var googleSignInButton: some View {
        Button {
            Task { await submitWithGoogle() }
        } label: {
            HStack(spacing: 10) {
                GoogleMark()
                Text("Continuar con Google")
                    .fontWeight(.medium)
            }
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(.white, in: .capsule)
            .overlay {
                Capsule().stroke(.black.opacity(0.15), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private var registerLink: some View {
        HStack(spacing: 4) {
            Text("¿No tienes cuenta?")
                .foregroundStyle(.secondary)
            Button("Crear cuenta") {
                showingRegister = true
            }
        }
        .font(.footnote)
        .sheet(isPresented: $showingRegister) {
            // Pasamos la sesión explícitamente: las hojas no siempre heredan
            // el entorno del presentador.
            RegisterView()
                .environment(session)
        }
    }

    private var environmentBadge: some View {
        Button {
            showingEnvironmentPicker = true
        } label: {
            Label(session.environment.displayName, systemImage: "antenna.radiowaves.left.and.right")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(.quaternary, in: Capsule())
        }
        .buttonStyle(.plain)
        .confirmationDialog("Cambiar entorno", isPresented: $showingEnvironmentPicker) {
            ForEach(APIEnvironment.allCases, id: \.self) { env in
                if env != session.environment {
                    Button(env.displayName) {
                        Task { await session.switchEnvironment(env) }
                    }
                }
            }
        } message: {
            Text("Servidor activo: \(session.environment.displayName)")
        }
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

    /// Lanza el SDK de Google, obtiene el ID token y se lo pasa a
    /// `AuthSession`. Si el usuario cancela el flujo (cierra la hoja de
    /// Google), no se muestra ningún error — es una acción deliberada, no un
    /// fallo.
    private func submitWithGoogle() async {
        guard !isSubmitting, let presenter = topViewController() else { return }
        errorMessage = nil
        isSubmitting = true
        defer { isSubmitting = false }

        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presenter)
            guard let idToken = result.user.idToken?.tokenString else {
                errorMessage = "Google no devolvió un token válido. Inténtalo de nuevo."
                return
            }
            try await session.signInWithGoogle(idToken: idToken)
        } catch let error as GoogleSignInError {
            errorMessage = message(for: error)
        } catch GIDSignInError.canceled {
            // Usuario canceló el flujo de Google: no es un error que mostrar.
        } catch {
            errorMessage = "No se pudo iniciar sesión con Google. Inténtalo de nuevo."
        }
    }

    /// Traduce el error de `signInWithGoogle` a un texto para la pantalla.
    private func message(for error: GoogleSignInError) -> String {
        switch error {
        case .invalidToken:
            "Google no pudo confirmar tu identidad. Inténtalo de nuevo."
        case .accountDisabled:
            "Tu cuenta está desactivada."
        case .emailConflict:
            "Ya tienes una cuenta con ese email. Entra con tu contraseña y vincula Google desde tu perfil."
        case .invalidData:
            "Revisa los datos introducidos."
        case .unexpected(let statusCode):
            "Error del servidor (\(statusCode)). Inténtalo más tarde."
        case .network:
            "No se pudo conectar. Comprueba tu conexión."
        }
    }

    /// El SDK de Google necesita un `UIViewController` sobre el que presentar
    /// su navegador embebido — SwiftUI no expone uno directamente.
    private func topViewController() -> UIViewController? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?
            .rootViewController
    }
}

#Preview {
    LoginView()
        .environment(AuthSession(initialState: .signedOut))
}
