//
//  AuthSession.swift
//  ommadawn
//
//  Estado de sesión de la app. Es el "modelo" que observa la UI: sabe si hay
//  usuario autenticado y expone iniciar/cerrar sesión.
//
//  Posee el cliente autenticado y el renovador — recuerda que ambos deben
//  crearse UNA vez y compartirse (cada renovador coordina sus propias
//  renovaciones). AuthSession es ese dueño único.
//

import Foundation
import Observation
import OmmadawnAPI

/// Motivos por los que un login puede fallar, en términos de la app.
///
/// Mapea los códigos del contrato a algo que la pantalla pueda mostrar. La UI
/// traduce cada caso a un texto; el modelo no guarda cadenas de interfaz.
enum LoginError: Error {
    case invalidCredentials   // 401 — usuario o contraseña incorrectos
    case accountDisabled      // 403 — cuenta desactivada
    case invalidData          // 422 — no debería pasar si validamos en cliente
    case unexpected(Int)      // cualquier otro estado no contemplado
    case network(Error)       // sin conexión / fallo de transporte
}

/// Motivos por los que un registro puede fallar.
enum RegisterError: Error {
    case alreadyTaken             // 409 — usuario o email ya en uso
    case invalidData              // 422 — datos rechazados por el servidor
    case registeredButLoginFailed // registró pero el auto-login falló (raro)
    case unexpected(Int)
    case network(Error)
}

@MainActor
@Observable
final class AuthSession {
    /// En qué punto está la sesión. La vista raíz enruta según esto.
    enum State {
        case loading          // arrancando: aún no sabemos si hay sesión
        case signedOut        // sin sesión → pantalla de login
        case signedIn(User)   // con sesión → app
    }

    private(set) var state: State = .loading

    private let environment: APIEnvironment
    private let tokenStore: TokenStore
    private let refresher: TokenRefresher

    /// El único cliente HTTP de la app (con `AuthMiddleware` ya cableado).
    /// Se expone para que otras features (p. ej. discografía) lo reutilicen
    /// en vez de crear un `Client` aparte, aunque sus endpoints sean públicos.
    let client: Client

    /// - Parameter tokenStore: inyectable para pruebas; por defecto el común.
    init(
        environment: APIEnvironment = .development,
        tokenStore: TokenStore = .shared,
        initialState: State = .loading
    ) {
        let refresher = TokenRefresher(tokenStore: tokenStore, environment: environment)
        self.environment = environment
        self.tokenStore = tokenStore
        self.refresher = refresher
        self.client = Client.authenticated(environment: environment, refresher: refresher)
        self.state = initialState
    }

    /// Al arrancar la app: si hay tokens guardados, valida la sesión pidiendo
    /// `/me`. Cualquier fallo (caducada, red) lleva a la pantalla de login.
    func restore() async {
        guard (try? await tokenStore.load()) != nil else {
            state = .signedOut
            return
        }
        do {
            state = .signedIn(try await fetchProfile())
        } catch {
            state = .signedOut
        }
    }

    /// Inicia sesión con username **o** email + contraseña.
    ///
    /// - Throws: siempre un `LoginError`, listo para que la pantalla lo pinte.
    func logIn(usernameOrEmail: String, password: String) async throws {
        do {
            let output = try await client.login_api_v1_auth_login_post(
                .init(body: .json(.init(
                    username_or_email: usernameOrEmail,
                    password: password
                )))
            )

            switch output {
            case .ok(let ok):
                let pair = try ok.body.json
                // Guarda tokens + caducidad (para el refresco proactivo).
                try await tokenStore.save(AuthTokens(pair: pair))
                // El login solo devuelve tokens; el perfil se pide aparte.
                state = .signedIn(try await fetchProfile())

            case .unauthorized:
                throw LoginError.invalidCredentials
            case .forbidden:
                throw LoginError.accountDisabled
            case .unprocessableContent:
                throw LoginError.invalidData
            case .undocumented(let statusCode, _):
                throw LoginError.unexpected(statusCode)
            }
        } catch let error as LoginError {
            throw error
        } catch {
            // Transporte, decodificación o /me fallando: todo cae aquí.
            throw LoginError.network(error)
        }
    }

    /// Registra un usuario nuevo y, si va bien, inicia sesión automáticamente.
    ///
    /// El endpoint de registro no devuelve tokens (solo el usuario creado), así
    /// que encadenamos un `logIn` con las mismas credenciales para dejar a la
    /// persona directamente dentro de la app.
    ///
    /// - Throws: siempre un `RegisterError`, listo para pintar en la pantalla.
    func register(username: String, email: String, password: String) async throws {
        do {
            let output = try await client.register_api_v1_auth_register_post(
                .init(body: .json(.init(username: username, email: email, password: password)))
            )
            switch output {
            case .created:
                try await logIn(usernameOrEmail: username, password: password)
            case .conflict:
                throw RegisterError.alreadyTaken
            case .unprocessableContent:
                throw RegisterError.invalidData
            case .undocumented(let statusCode, _):
                throw RegisterError.unexpected(statusCode)
            }
        } catch let error as RegisterError {
            throw error
        } catch is LoginError {
            // La cuenta se creó, pero el auto-login falló. Que inicie sesión
            // a mano desde la pantalla de login.
            throw RegisterError.registeredButLoginFailed
        } catch {
            throw RegisterError.network(error)
        }
    }

    /// Cierra la sesión: intenta revocar en el servidor y limpia el local.
    ///
    /// La revocación es *best-effort*: aunque falle (sin red), la sesión local
    /// se borra igual. Lo que nunca puede pasar es quedarnos "medio dentro".
    func logOut() async {
        // 1) Cierre local INMEDIATO, sin tocar la red. Estas operaciones son
        //    locales (Keychain, ~ms), así que la UI responde al instante
        //    aunque el servidor esté caído o lento.
        let tokens = try? await tokenStore.load()
        try? await tokenStore.clear()
        state = .signedOut

        // 2) Revocación en el servidor: best-effort, en segundo plano. No
        //    bloquea el cierre de sesión; si no hay red, da igual, ya estamos
        //    fuera. Lleva el token capturado porque el Keychain ya está limpio.
        if let tokens {
            Task { await Client.revokeSession(tokens, environment: environment) }
        }
    }

    // MARK: - Privado

    private func fetchProfile() async throws -> User {
        let output = try await client.me_api_v1_auth_me_get(.init())
        switch output {
        case .ok(let ok):
            return try ok.body.json
        case .unauthorized:
            throw AuthError.sessionExpired
        case .undocumented(let statusCode, _):
            throw AuthError.unexpectedStatus(statusCode)
        }
    }
}
